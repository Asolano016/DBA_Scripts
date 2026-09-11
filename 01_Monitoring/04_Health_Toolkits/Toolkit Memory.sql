/******************************************************************************
SQL SERVER MEMORY HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This script provides a structured approach for analyzing SQL Server memory
usage and identifying common memory-related issues.

AREAS COVERED

1. SQL Server process memory usage
2. Target vs Total Server Memory
3. Memory configuration
4. Memory clerks distribution
5A. Memory Grant Execution Plan Analysis
5B. Active memory grants
6. Waiting memory grants
7. Historical memory grant consumers
8. Page Life Expectancy (PLE)
9. Plan Cache analysis
10. AdHoc cache analysis
11. Buffer Pool distribution
12. Resource Semaphores
13. Executive Summary

HOW TO USE

Run the entire script and review sections in order.

Recommended troubleshooting sequence:

    1. Executive Summary
    2. Process Memory
    3. Target vs Total Memory
    4. Memory Clerks
    5. Resource Semaphores
    6. Memory Grant Execution Plan Analysis/ Active Memory Grants
    7. Historical Memory Grants
    8. Plan Cache
    9. Buffer Pool Distribution

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    SQL SERVER PROCESS MEMORY
-----------------------------------------------------------------------------

.PURPOSE

    Show memory consumed by the SQL Server process (sqlservr.exe).

.WHY THIS MATTERS

    Helps determine whether SQL Server is experiencing memory pressure from the operating system.

.KEY METRICS
    SQLMemoryMB

        Memory currently used by SQL Server.

    LockedPagesMB

        Memory protected using Lock Pages In Memory.

   memory_utilization_percentage

   Percentage of committed memory currently utilized.

    process_physical_memory_low

        0 = Heatthy
        1 = Physical memory pressure detected

    process_virtual_memory_low

        0 = Healthy
        1 = Virtual memory pressure detected

.HEALTHY

    process_physical_memory_low = 0

    process_virtual_memory_low = 0

.WARNING

    process_physical_memory_low = 1

    process_virtual_memory_low = 1

.POSSIBLE CAUSES

    OS memory pressure
    External processes consuming RAM
    Max Server Memory misconfiguration

.NEXT ACTIONS

    Review OS memory usage.
    Review Max Server Memory configuration.
    Review external applications consuming memory.

-------------------------------------------------------------------------------*/

SELECT GETDATE() AS CaptureTime
      ,physical_memory_in_use_kb / 1024 AS SQLMemoryMB
      ,locked_page_allocations_kb / 1024 AS LockedPagesMB
      ,memory_utilization_percentage
      ,process_physical_memory_low
      ,process_virtual_memory_low
FROM sys.dm_os_process_memory;
GO

/*-------------------------------------------------------------------------------
    SECTION 2
    TARGET SERVER MEMORY VS TOTAL SERVER MEMORY
-------------------------------------------------------------------------------

.PURPOSE

    Compare desired memory versus allocated memory.

.WHY THIS MATTERS

    Indicates whether SQL Server has reached its memory target.

.KEY METRICS

    Target Server Memory

        Memory SQL Server wants to allocate.

    Total Server Memory

        Memory currently allocated.

.HEALTHY

    Total Server Memory approximately equals Target Server Memory.

.WARNING

    Total Server Memory remains significantly below Target Server Memory.

.POSSIBLE CAUSES

    External memory pressure
    Recent SQL Server startup
    Memory limitations imposed by the OS

.NEXT ACTIONS

    Validate Max Server Memory.
    Review OS memory consumption.
    Review SQL startup history.

-------------------------------------------------------------------------------*/

SELECT counter_name
      ,cntr_value / 1024 AS MB
FROM sys.dm_os_performance_counters
WHERE counter_name IN ('Target Server Memory (KB)','Total Server Memory (KB)');
GO

/*-------------------------------------------------------------------------------
    SECTION 3
    MEMORY CONFIGURATION
-------------------------------------------------------------------------------

.PURPOSE

    Review SQL Server memory settings.

.WHY THIS MATTERS

    Incorrect memory settings may cause SQL Server or Windows to compete
    for RAM resources.

.KEY METRICS

    min server memory

    max server memory

.HEALTHY

    Max Server Memory leaves sufficient RAM for the OS.

.WARNING

    Max Server Memory configured near total server RAM.

.POSSIBLE CAUSES

    Improper server sizing
    Legacy SQL Server configuration

.NEXT ACTIONS

    Review server RAM.
    Reserve memory for OS and monitoring tools.
    Adjust Max Server Memory if required.

-------------------------------------------------------------------------------*/

SELECT name
      ,value_in_use
FROM sys.configurations
WHERE name LIKE '%memory%';
GO

/*-------------------------------------------------------------------------------
    SECTION 4
    MEMORY CLERKS
-------------------------------------------------------------------------------

.PURPOSE

    Identify where SQL Server memory is being allocated.

.WHY THIS MATTERS

    Memory problems are often identified by determining which memory clerk
    owns the largest portion of memory.

.KEY METRICS

    MEMORYCLERK_SQLBUFFERPOOL

    CACHESTORE_SQLCP

    CACHESTORE_OBJCP

    OBJECTSTORE_LOCK_MANAGER

    MEMORYCLERK_XTP

.HEALTHY

    MEMORYCLERK_SQLBUFFERPOOL is the dominant consumer.

.WARNING

    Unexpected memory clerks consuming large amounts of memory.

.POSSIBLE CAUSES

    Plan cache pollution
    Excessive locking
    In-Memory OLTP usage
    Application-specific memory patterns

.NEXT ACTIONS

    Investigate the largest memory clerk.
    Review plan cache sections if SQLCP is large.
    Review blocking if Lock Manager usage is large.

-------------------------------------------------------------------------------*/

SELECT type
      ,SUM(pages_kb) / 1024 AS MB
FROM sys.dm_os_memory_clerks
GROUP BY type
ORDER BY MB DESC;
GO

/*-------------------------------------------------------------------------------
    SECTION 5A
    MEMORY GRANT EXECUTION PLAN ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Retrieve execution plans for queries holding large memory grants.

.WHY THIS MATTERS

    Helps identify operators responsible for excessive memory usage.

.KEY OPERATORS

    Sort

    Hash Match

    Hash Aggregate

    Index Build

.HEALTHY

    Memory grant size aligns with actual memory consumption.

.WARNING

    Large grants associated with small actual memory usage.

.POSSIBLE CAUSES

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