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
    Identify queries historically requesting the largest memory grants.
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
    Sudden steep drop or continuous low values (<300s).
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
    Monitor memory grant resource pool semaphores.

.KEY METRICS
    target_memory_kb: Memory target for grants.
    max_target_memory_kb: Maximum grant ceiling.
    total_memory_kb: Current allocated grant memory.
    available_memory_kb: Memory free for new grants.
    grantee_count: Active grant holders.
    waiter_count: Queries blocked waiting for grants.

.HEALTHY
    waiter_count = 0.
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
    Provide high-level memory health summary.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT cntr_value / 1024 FROM sys.dm_os_performance_counters WHERE counter_name = 'Total Server Memory (KB)' AND object_name LIKE '%Memory Manager%') AS TotalServerMemoryMB,
    (SELECT cntr_value / 1024 FROM sys.dm_os_performance_counters WHERE counter_name = 'Target Server Memory (KB)' AND object_name LIKE '%Memory Manager%') AS TargetServerMemoryMB,
    (SELECT physical_memory_in_use_kb / 1024 FROM sys.dm_os_process_memory) AS ProcessMemoryInUseMB,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants WHERE grant_time IS NULL) AS WaitingMemoryGrants,
    (SELECT process_physical_memory_low FROM sys.dm_os_process_memory) AS OSMemoryPressureFlag;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
MEMORY SYMPTOM                      ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
Waiting Memory Grants > 0           --> Review Active Grants (5B) & Schedulers
process_physical_memory_low = 1     --> OS memory starvation; review Max Server Memory
Steep PLE Drop on specific NUMA     --> Large table scan on node; check Missing Indexes
High Adhoc Single-Use MB (>1 GB)    --> Enable 'optimize for ad hoc workloads'
High CACHESTORE_SQLCP               --> Investigate unparameterized dynamic queries
******************************************************************************/


    Poor cardinality estimates
    Outdated statistics
    Missing indexes

.NEXT ACTIONS

    Review execution plans.
    Update statistics.
    Tune queries and indexes.

-------------------------------------------------------------------------------*/

SELECT mg.granted_memory_kb / 1024 AS GrantedMB
      ,mg.session_id
      ,t.text
      ,qp.query_plan
FROM sys.dm_exec_query_memory_grants AS mg
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) AS t
CROSS APPLY sys.dm_exec_query_plan(mg.plan_handle) AS qp
ORDER BY mg.granted_memory_kb DESC
GO

/*-----------------------------------------------------------------------------
    SECTION 5B
    ACTIVEMEMORY GRANTS
-----------------------------------------------------------------------------

.PURPOSE
    Show queries currently holdingmemory grants.

.WHY THIS MATTERS
    Excessive grants can reduce concurrency and delay other queries.
.KEY METRICS

    RequestedMB

    GrantedMB

    UsedMB

    MaxUsedMB

.HEALTHY

    GrantedMB is close to UsedMB.

.WARNING

    GrantedMB significantly exceeds UsedMB.

.POSSIBLE CAUSES

    Stale statistics
    Cardinality estimation issues
    Parameter sniffing
    Inefficient execution plans

.NEXT ACTIONS

    Capture execution plans.
    Compare estimated versus actual rows.
    Review statistics quality.

-------------------------------------------------------------------------------*/

SELECT mg.session_id
      ,mg.requested_memory_kb / 1024 AS RequestedMB
      ,mg.granted_memory_kb / 1024 AS GrantedMB
      ,mg.used_memory_kb / 1024 AS UsedMB
      ,mg.max_used_memory_kb / 1024 AS MaxUsedMB
      ,r.status
      ,DB_NAME(r.database_id) AS DatabaseName
      ,t.text
FROM sys.dm_exec_query_memory_grants mg
LEFT JOIN sys.dm_exec_requests r ON mg.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(mg.sql_handle) t
ORDER BY mg.granted_memory_kb DESC;
GO

/*-------------------------------------------------------------------------------
    SECTION 6
    WAITING MEMORY GRANTS
-------------------------------------------------------------------------------

.PURPOSE

    Identify queries waiting for memory grants.

.WHY THIS MATTERS

    Waiting memory grants indicate query memory contention.

.HEALTHY

    No rows returned.

.WARNING

    One or more waiting sessions.

.POSSIBLE CAUSES

    Large Sort operations
    Hash Join operations
    Index maintenance
    Excessive active grants

.NEXT ACTIONS

    Review Sections 5, 5A and 12.
    Analyze memory-intensive queries.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_exec_query_memory_grants
WHERE grant_time IS NULL;
GO

/*-------------------------------------------------------------------------------
    SECTION 7
    HISTORICAL TOP MEMORY GRANTS
-------------------------------------------------------------------------------

.PURPOSE

    Identify historically expensive memory consumers.

.WHY THIS MATTERS

    Helps locate recurring memory-intensive queries.

.HEALTHY

    MaxGrantMB is reasonably aligned with MaxUsedGrantMB.

.WARNING

    Large differences between grant size and actual usage.

.POSSIBLE CAUSES

    Overestimated cardinality
    Poor query design
    Missing indexes

.NEXT ACTIONS

    Review execution plans.
    Validate statistics.
    Consider query tuning.

-------------------------------------------------------------------------------*/

SELECT TOP (20) qs.max_grant_kb / 1024 AS MaxGrantMB
       ,qs.max_used_grant_kb / 1024 AS MaxUsedGrantMB
       ,qs.execution_count
       ,st.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.max_grant_kb DESC;

GO

/*-----------------------------------------------------------------------------
    SECTION 8
    PAGE LIFE EXPECTANCY (PLE)
-------------------------------------------------------------------------------

.PURPOSE

    Measure how long pages remain in Buffer Pool.

.WHY THIS MATTERS

    Sudden drops often indicate increased memory pressure.

.HEALTHY

    Stable or consistently increasing values.

.WARNING

    Continuous or sudden declines.

.POSSIBLE CAUSES

    Large scans
    Missing indexes
    Memory pressure
    Workload spikes

.NEXT ACTIONS

    Review query activity.
    Review Buffer Pool usage.
    Review missing indexes.

-------------------------------------------------------------------------------*/

SELECT cntr_value AS PageLifeExpectancy
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy';
GO

/*-------------------------------------------------------------------------------
    SECTION 9
    PLAN CACHE DISTRIBUTION
-------------------------------------------------------------------------------

.PURPOSE

    Understand how execution plan cache memory is distributed.

.COMMON TYPES

    Proc
    Prepared
    Adhoc

.WARNING

    Excessive Adhoc plans often indicate cache pollution.

.NEXT ACTIONS

    Review Adhoc cache growth.
    Review application parameterization practices.

-------------------------------------------------------------------------------*/

SELECT objtype
      ,COUNT(*) AS Plans
      ,SUM(size_in_bytes) / 1024 / 1024 AS SizeMB
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY SizeMB DESC;
GO

/*-------------------------------------------------------------------------------
    SECTION 10
    ADHOC PLAN CACHE ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Measure memory consumed specifically by Adhoc plans.

.WHY THIS MATTERS

    Adhoc plans can waste significant memory.

.HEALTHY

    Adhoc plans represent a small percentage of plan cache.

.WARNING

    Thousands of single-use plans.
    Multiple GB consumed by Adhoc cache.

.POSSIBLE CAUSES

    Literal-based queries
    Poor parameterization strategy

.NEXT ACTIONS

    Review Optimize for Ad Hoc Workloads.
    Review Forced Parameterization.

-------------------------------------------------------------------------------*/

SELECT COUNT(*) AS NumberOfPlans
      ,SUM(size_in_bytes) / 1024 / 1024 AS CacheSizeMB
FROM sys.dm_exec_cached_plans
WHERE objtype = 'Adhoc';
GO

/*-------------------------------------------------------------------------------
    SECTION 11
    BUFFER POOL DISTRIBUTION BY DATABASE
-------------------------------------------------------------------------------

.PURPOSE

    Identify databases consuming Buffer Pool memory.

.WHY THIS MATTERS

    Helps determine workload distribution across databases.

.HEALTHY

    Largest consumers correlate with most active databases.

.WARNING

    Unexpected database consuming a large portion of memory.

.POSSIBLE CAUSES

    Large scans
    Reporting workloads
    ETL activity

.NEXT ACTIONS

    Investigate workload patterns.
    Review index efficiency.

-------------------------------------------------------------------------------*/

SELECT DB_NAME(database_id) AS DatabaseName
      ,COUNT(*) * 8 / 1024 AS CachedMB
FROM sys.dm_os_buffer_descriptors
WHERE database_id <> 32767
GROUP BY database_id
ORDER BY CachedMB DESC;
GO

/*-------------------------------------------------------------------------------
    SECTION 12
    RESOURCE SEMAPHORES
-------------------------------------------------------------------------------

.PURPOSE

    Monitor memory grant resource availability.

.WHY THIS MATTERS

    Resource Semaphores control query memory grants.

.KEY METRICS

    available_memory_kb

    granted_memory_kb

    grantee_count

    waiter_count

.HEALTHY

    waiter_count = 0

.WARNING

    waiter_count > 0

.POSSIBLE CAUSES

    Memory grant contention
    Large sorting operations
    Hash processing
    Query overestimation

.NEXT ACTIONS

    Review Active Memory Grants.
    Review Waiting Memory Grants.
    Identify largest grant consumers.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_exec_query_resource_semaphores;
GO

/*-------------------------------------------------------------------------------
    SECTION 13
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------

.PURPOSE

    Provide a quick memory health assessment.

.HEALTHY ENVIRONMENT

    TotalMemory approximately equals TargetMemory.

    WaitingMemoryGrants = 0.

    process_physical_memory_low = 0.

    Stable Page Life Expectancy.

    Buffer Pool is largest memory consumer.

.INVESTIGATE

    WaitingMemoryGrants > 0.

    process_physical_memory_low = 1.

    Repeated PLE declines.

    Excessive Adhoc cache.

    Large memory grant overestimations.

.NEXT ACTIONS

    Memory Grants:
        Review Sections 5, 5A, 6 and 12.

    Plan Cache:
        Review Sections 9 and 10.

    Memory Pressure:
        Review Sections 1 and 2.

-------------------------------------------------------------------------------*/

SELECT (SELECT cntr_value / 1024
        FROM sys.dm_os_performance_counters
        WHERE counter_name = 'Total Server Memory (KB)'
        AND object_name LIKE '%Memory Manager%') AS TotalMemoryMB
      ,(SELECT cntr_value / 1024
        FROM sys.dm_os_performance_counters
        WHERE counter_name = 'Target Server Memory (KB)'
        AND object_name LIKE '%Memory Manager%') AS TargetMemoryMB
      ,(SELECT physical_memory_in_use_kb / 1024
        FROM sys.dm_os_process_memory) AS ProcessMemoryMB
      ,(SELECT COUNT(*)
        FROM sys.dm_exec_query_memory_grants
        WHERE grant_time IS NULL) AS WaitingMemoryGrants;
GO