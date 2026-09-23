/******************************************************************************
SQL SERVER MEMORY HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This script provides a structured approach for analyzing SQL Server memory
usage, identifying buffer pool pressure, memory clerk distributions, memory grant
contention, and plan cache bloat.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. SQL Server Process Memory & OS Pressure
2. Target vs Total Server Memory
3. Memory Configuration Settings
4. Memory Clerks Distribution
5A. Memory Grant Execution Plan Analysis
5B. Active Memory Grants
6. Waiting Memory Grants
7. Historical Top Memory Grant Consumers
8. Page Life Expectancy (PLE) by NUMA Node
9. Plan Cache Memory Distribution
10. Ad-Hoc Plan Cache Analysis
11. Buffer Pool Distribution by Database
12. Query Resource Semaphores
13. Executive Summary & Triage Matrix

RECOMMENDED TROUBLESHOOTING SEQUENCE

    1. Executive Summary
    2. Process Memory & OS Pressure
    3. Target vs Total Memory
    4. Resource Semaphores & Waiting Memory Grants
    5. Active & Historical Memory Grants
    6. PLE by NUMA Node
    7. Memory Clerks & Buffer Pool Distribution

HOW TO READ THIS SCRIPT

    Use this script in order from Section 1 to Section 13. The first checks answer
    the basic questions: is SQL Server under OS memory pressure, is it using the
    configured memory, and are queries waiting on memory grants?

    After the overview checks, correlate the symptoms across the sections:

    - Total Server Memory far below Target Server Memory generally means SQL Server
      is under-using its memory ceiling, or that another workload is competing for RAM.
    - process_physical_memory_low = 1 indicates OS memory pressure; review max server
      memory configuration and non-SQL memory consumers.
    - Waiting Memory Grants > 0 indicates grant contention; focus on Sections 5B and 6.
    - GrantedMB far above MaxUsedMB suggests the query is overestimating row counts,
      often because of stale statistics, poor cardinality estimates, or inefficient plans.
    - Low or declining PLE values suggest buffer pool churn, large scans, or memory strain.
    - Large ad-hoc or single-use plans indicate plan cache bloat and poor parameterization.
    - A dominant buffer pool with poor plan reuse usually indicates workload pressure,
      not just a lack of physical RAM.

    The strongest diagnosis comes from reviewing multiple sections together rather than
    interpreting a single metric in isolation. A healthy memory condition typically
    shows stable memory configuration, low waiting grants, reasonable PLE, and no severe
    ad-hoc plan cache explosion.

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    SQL SERVER PROCESS MEMORY & OS PRESSURE
-------------------------------------------------------------------------------
.PURPOSE
    Show memory consumed by the SQL Server process (sqlservr.exe) and OS signals.

.WHY THIS MATTERS
    Helps determine whether SQL Server is experiencing external memory pressure from Windows.

.KEY METRICS
    SQLMemoryMB: Memory currently committed and used by SQL Server.
    LockedPagesMB: Memory protected using Lock Pages In Memory (LPIM).
    memory_utilization_percentage: Percentage of committed memory currently in working set.
    process_physical_memory_low: 0 = Healthy, 1 = Physical memory pressure detected by OS.
    process_virtual_memory_low: 0 = Healthy, 1 = Virtual memory pressure detected.

.HEALTHY
    process_physical_memory_low = 0
    process_virtual_memory_low = 0

.WARNING
    process_physical_memory_low = 1
-----------------------------------------------------------------------------*/

SELECT
    GETDATE() AS CaptureTime,
    physical_memory_in_use_kb / 1024 AS SQLMemoryMB,
    locked_page_allocations_kb / 1024 AS LockedPagesMB,
    memory_utilization_percentage,
    process_physical_memory_low,
    process_virtual_memory_low
FROM sys.dm_os_process_memory;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    TARGET SERVER MEMORY VS TOTAL SERVER MEMORY
-------------------------------------------------------------------------------
.PURPOSE
    Compare target desired memory versus currently allocated dynamic memory.

.WHY THIS MATTERS
    Indicates whether SQL Server has ramped up to its configured ceiling or is shrinking.

.HEALTHY
    Total Server Memory approximately equals Target Server Memory (after warmup).

.WARNING
    Total Server Memory drops significantly below Target Server Memory under load.
-----------------------------------------------------------------------------*/

SELECT
    counter_name,
    cntr_value / 1024 AS MemoryMB
FROM sys.dm_os_performance_counters
WHERE counter_name IN ('Target Server Memory (KB)', 'Total Server Memory (KB)')
  AND object_name LIKE '%Memory Manager%';
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    MEMORY CONFIGURATION
-------------------------------------------------------------------------------
.PURPOSE
    Review SQL Server min/max memory settings.

.WHY THIS MATTERS
    Ensures adequate RAM is left for Windows OS, drivers, and external processes.
-----------------------------------------------------------------------------*/

SELECT
    name,
    value_in_use,
    description
FROM sys.configurations
WHERE name IN
(
    'min server memory (MB)',
    'max server memory (MB)',
    'optimize for ad hoc workloads',
    'min memory per query (KB)'
);
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    MEMORY CLERKS DISTRIBUTION
-------------------------------------------------------------------------------
.PURPOSE
    Identify where SQL Server engine memory is allocated across internal components.

.KEY CLERKS
    MEMORYCLERK_SQLBUFFERPOOL: Buffer pool (data and index pages)
    CACHESTORE_SQLCP: SQL Plan Cache (Ad-hoc and prepared plans)
    CACHESTORE_OBJCP: Object Plan Cache (Procedures, functions, triggers)
    OBJECTSTORE_LOCK_MANAGER: Lock memory structures
    MEMORYCLERK_XTP: In-Memory OLTP engine

.HEALTHY
    MEMORYCLERK_SQLBUFFERPOOL is the dominant consumer (typically >60-80%).
-----------------------------------------------------------------------------*/

SELECT TOP (15)
    type AS ClerkType,
    SUM(pages_kb) / 1024 AS MemoryMB
FROM sys.dm_os_memory_clerks
GROUP BY type
ORDER BY MemoryMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5A
    MEMORY GRANT EXECUTION PLAN ANALYSIS
-------------------------------------------------------------------------------
.PURPOSE
    Retrieve execution plans for queries holding large workspace memory grants.

.WHY THIS MATTERS
    Identifies expensive SORT, HASH JOIN, or HASH AGGREGATE operators.
-----------------------------------------------------------------------------*/

SELECT TOP (10)
    mg.session_id,
    mg.granted_memory_kb / 1024 AS GrantedMB,
    mg.requested_memory_kb / 1024 AS RequestedMB,
    mg.used_memory_kb / 1024 AS UsedMB,
    mg.max_used_memory_kb / 1024 AS MaxUsedMB,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS StatementText,
    qp.query_plan
FROM sys.dm_exec_query_memory_grants AS mg
LEFT JOIN sys.dm_exec_requests AS r
    ON mg.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(mg.plan_handle) AS qp
ORDER BY mg.granted_memory_kb DESC
OPTION (MAXDOP 1);
GO

/*-----------------------------------------------------------------------------
    SECTION 5B
    ACTIVE MEMORY GRANTS & CONCURRENCY
-------------------------------------------------------------------------------
.PURPOSE
    Show queries currently holding workspace memory grants and efficiency.

.HEALTHY
    GrantedMB is reasonably aligned with UsedMB and MaxUsedMB.

.WARNING
    GrantedMB is drastically higher than MaxUsedMB (cardinality overestimation).
-----------------------------------------------------------------------------*/

SELECT
    mg.session_id,
    mg.requested_memory_kb / 1024 AS RequestedMB,
    mg.granted_memory_kb / 1024 AS GrantedMB,
    mg.used_memory_kb / 1024 AS UsedMB,
    mg.max_used_memory_kb / 1024 AS MaxUsedMB,
    mg.dop AS DOP,
    mg.grant_time,
    r.status,
    DB_NAME(r.database_id) AS DatabaseName,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS StatementText
FROM sys.dm_exec_query_memory_grants mg
LEFT JOIN sys.dm_exec_requests r
    ON mg.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) st
ORDER BY mg.granted_memory_kb DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    WAITING MEMORY GRANTS
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries queued waiting for workspace memory grants.

.HEALTHY
    No rows returned (waiter_count = 0).

.WARNING
    Sessions waiting with grant_time IS NULL (causes application timeouts).
-----------------------------------------------------------------------------*/

SELECT
    mg.session_id,
    mg.request_time,
    mg.requested_memory_kb / 1024 AS RequestedMB,
    mg.dop AS RequestedDOP,
    mg.queue_id,
    mg.wait_order,
    r.status,
    r.wait_type,
    r.wait_time AS WaitTimeMs,
    DB_NAME(r.database_id) AS DatabaseName,
    st.text AS BatchText
FROM sys.dm_exec_query_memory_grants mg
LEFT JOIN sys.dm_exec_requests r
    ON mg.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) st
WHERE mg.grant_time IS NULL
ORDER BY mg.wait_order;
GO

/*-----------------------------------------------------------------------------
    SECTION 7
    HISTORICAL TOP MEMORY GRANTS
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries that historically requested the largest memory grants.

.WHY THIS MATTERS
    Recurring heavy grant requests often point to queries with unstable plans,
    stale statistics, or poor cardinality estimates that hit the server repeatedly.

.HEALTHY
    MaxGrantMB and MaxUsedGrantMB are close together, and no single query dominates.

.WARNING
    Large gap between grant size and actual usage, or a few queries repeatedly at the top.

.POSSIBLE CAUSES
    Overestimated row counts, stale stats, parameter sniffing, missing indexes,
    inefficient hash/sort operations.

.NEXT ACTIONS
    Review execution plans, update statistics, and tune the top memory-heavy queries.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.max_grant_kb / 1024 AS MaxGrantMB,
    qs.max_used_grant_kb / 1024 AS MaxUsedGrantMB,
    (qs.max_grant_kb - qs.max_used_grant_kb) / 1024 AS UnusedGrantMB,
    qs.total_worker_time / 1000 AS TotalCPUms,
    qs.last_execution_time,
    SUBSTRING(
        st.text,
        (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2) + 1
    ) AS StatementText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.max_grant_kb DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    PAGE LIFE EXPECTANCY (PLE) BY NUMA NODE
-------------------------------------------------------------------------------
.PURPOSE
    Measure how long pages remain in the buffer pool across NUMA nodes.

.WHY THIS MATTERS
    In multi-NUMA systems, a single NUMA node under memory pressure can degrade
    performance while server-wide average PLE looks deceptively healthy.

.HEALTHY
    PLE is stable and exceeds (Data Cache GB / 4 GB) * 300 seconds per node.

.WARNING
    Sudden steep drop or continuous low values (<300s), especially on one NUMA node.

.POSSIBLE CAUSES
    Large scans, missing indexes, memory pressure, skewed workload distribution,
    cache churn across a subset of NUMA nodes.

.NEXT ACTIONS
    Review the workload per NUMA node, check missing indexes, and investigate queries
    causing repeated buffer pool churn.
-----------------------------------------------------------------------------*/

SELECT
    instance_name AS [NUMANode / CounterInstance],
    counter_name,
    cntr_value AS PageLifeExpectancySeconds
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy'
  AND object_name LIKE '%Buffer Node%';
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    PLAN CACHE MEMORY DISTRIBUTION
-------------------------------------------------------------------------------
.PURPOSE
    Analyze how execution plan cache memory is divided across object types.

.WHY THIS MATTERS
    A large plan cache can be healthy, but abnormal growth in one object family often
    points to bad parameterization, repeated compile churn, or cache pollution.

.HEALTHY
    Cache is distributed reasonably and ad-hoc / single-use plans are not dominating.

.WARNING
    Very large single-use or ad-hoc plan contribution, or plan cache dominated by a few
    object types with repeated churn.

.POSSIBLE CAUSES
    Literal-based queries, poor parameterization, ORM-generated SQL, excessive recompiles,
    application-level query churn.

.NEXT ACTIONS
    Review ad-hoc plan growth, parameterize frequently repeated queries, and check for
    unnecessary recompile patterns.
-----------------------------------------------------------------------------*/

SELECT
    objtype,
    COUNT(*) AS PlanCount,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS CacheSizeMB,
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS SingleUsePlans,
    SUM(CASE WHEN usecounts = 1 THEN CAST(size_in_bytes AS BIGINT) ELSE 0 END) / 1024 / 1024 AS SingleUseSizeMB
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY CacheSizeMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    AD-HOC PLAN CACHE ANALYSIS
-------------------------------------------------------------------------------
.PURPOSE
    Measure memory consumed specifically by single-use ad-hoc plans.

.WHY THIS MATTERS
    Ad-hoc SQL is often the main source of plan cache bloat. Large single-use plans can
    consume significant memory without providing reuse value.

.HEALTHY
    Ad-hoc plans are a small share of the plan cache, and most queries are reused.

.WARNING
    High TotalAdhocPlans, large AdhocCacheMB, or SingleUseAdhocMB growing into GBs.

.POSSIBLE CAUSES
    Literal-based SQL, poor parameterization, dynamic SQL generation, ORMs, reporting tools.

.NEXT ACTIONS
    Enable optimize for ad hoc workloads, improve parameterization, and review the most
    common SQL text patterns driving plan churn.
-----------------------------------------------------------------------------*/

SELECT
    COUNT(*) AS TotalAdhocPlans,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS AdhocCacheMB,
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS SingleUseAdhocPlans,
    SUM(CASE WHEN usecounts = 1 THEN CAST(size_in_bytes AS BIGINT) ELSE 0 END) / 1024 / 1024 AS SingleUseAdhocMB
FROM sys.dm_exec_cached_plans
WHERE objtype = 'Adhoc';
GO

/*-----------------------------------------------------------------------------
    SECTION 11
    BUFFER POOL DISTRIBUTION BY DATABASE
-------------------------------------------------------------------------------
.PURPOSE
    Identify databases consuming Buffer Pool RAM.

.WHY THIS MATTERS
    Buffer pool usage shows which databases are actively caching pages in memory. A single
    database dominating the buffer pool may be driving memory pressure or heavy scan activity.

.HEALTHY
    Memory usage is spread across active databases in a way that matches workload demand.

.WARNING
    One database unexpectedly owns most of the buffer pool, especially when no corresponding
    workload pattern explains it.

.POSSIBLE CAUSES
    Large scans, reporting workloads, ETL spikes, poor indexing, tempdb-related churn.

.NEXT ACTIONS
    Investigate the dominant database, review index efficiency, and correlate with query activity.

.CAUTION
    Scanning sys.dm_os_buffer_descriptors iterates over all memory buffers.
    On enterprise servers with >256 GB RAM, run this during off-peak or when necessary.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    COALESCE(DB_NAME(database_id), 'ResourceDb / Free') AS DatabaseName,
    COUNT_BIG(*) * 8 / 1024 AS CachedMB,
    CAST(COUNT_BIG(*) * 100.0 / NULLIF(SUM(COUNT_BIG(*)) OVER(), 0) AS DECIMAL(5,2)) AS BufferPoolPercentage
FROM sys.dm_os_buffer_descriptors
WHERE database_id <> 32767
GROUP BY database_id
ORDER BY CachedMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 12
    QUERY RESOURCE SEMAPHORES
-------------------------------------------------------------------------------
.PURPOSE
    Monitor memory grant resource pool semaphores and query queue pressure.

.WHY THIS MATTERS
    Resource semaphores show whether SQL Server is exhausting grant memory and forcing queries
    to wait for a grant slot. This is the direct signal of memory grant contention.

.KEY METRICS
    target_memory_kb: Memory target for grants.
    max_target_memory_kb: Maximum grant ceiling.
    total_memory_kb: Current allocated grant memory.
    available_memory_kb: Memory free for new grants.
    grantee_count: Active grant holders.
    waiter_count: Queries blocked waiting for grants.

.HEALTHY
    waiter_count = 0 and available_memory_kb remains consistent.

.WARNING
    waiter_count > 0, available_memory_kb low, or many queries queued behind a few grant holders.

.POSSIBLE CAUSES
    Large sorts, hash joins, memory-intensive plans, bad estimates, too many concurrent big queries.

.NEXT ACTIONS
    Review active and waiting memory grants, then identify the queries consuming the largest grants.
-----------------------------------------------------------------------------*/

SELECT
    resource_semaphore_id,
    target_memory_kb / 1024 AS TargetMemoryMB,
    max_target_memory_kb / 1024 AS MaxTargetMemoryMB,
    total_memory_kb / 1024 AS TotalMemoryMB,
    available_memory_kb / 1024 AS AvailableMemoryMB,
    granted_memory_kb / 1024 AS GrantedMemoryMB,
    used_memory_kb / 1024 AS UsedMemoryMB,
    grantee_count,
    waiter_count,
    timeout_error_count
FROM sys.dm_exec_query_resource_semaphores;
GO

/*-----------------------------------------------------------------------------
    SECTION 13
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    Provide a quick memory health assessment for triage and action prioritization.

.WHY THIS MATTERS
    This summary gives the first-pass answer: is the system under memory pressure,
    is memory grant contention active, and does the current picture align with a healthy setup?

.HEALTHY
    Total Server Memory is close to Target Server Memory, WaitingMemoryGrants = 0,
    and OSMemoryPressureFlag = 0.

.WARNING
    WaitingMemoryGrants > 0, OSMemoryPressureFlag = 1, or Total Server Memory is far below target.

.POSSIBLE CAUSES
    Memory pressure from the OS, grant contention, poor plan reuse, large scans,
    or excessive ad-hoc SQL.

.NEXT ACTIONS
    Use this section as the entry point: if the summary is negative, drill into the relevant
    sections for grants, plan cache, PLE, and configuration.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT cntr_value / 1024 FROM sys.dm_os_performance_counters WHERE counter_name = 'Total Server Memory (KB)' AND object_name LIKE '%Memory Manager%') AS TotalServerMemoryMB,
    (SELECT cntr_value / 1024 FROM sys.dm_os_performance_counters WHERE counter_name = 'Target Server Memory (KB)' AND object_name LIKE '%Memory Manager%') AS TargetServerMemoryMB,
    (SELECT physical_memory_in_use_kb / 1024 FROM sys.dm_os_process_memory) AS ProcessMemoryInUseMB,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants WHERE grant_time IS NULL) AS WaitingMemoryGrants,
    (SELECT process_physical_memory_low FROM sys.dm_os_process_memory) AS OSMemoryPressureFlag;
GO
