/******************************************************************************
SQL SERVER PLAN CACHE HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a structured approach for investigating SQL Server Plan Cache
memory consumption, single-use ad-hoc plan bloat, procedure cache efficiency,
plan recompilations, and cache store memory distribution.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Plan Cache Memory Distribution by Object Type
2. Ad-Hoc Plan Cache Bloat & Single-Use Plans
3. Top Single-Use Ad-Hoc Statements Consuming Cache
4. Largest Individual Cached Plans in Memory
5. Most Frequently Executed Cached Statements
6. Top CPU Consuming Cached Statements
7. Stored Procedure Cache Utilization
8. Stored Procedures by Execution & Recompile Indicators
9. Plan Cache Reuse Distribution (Use Count Buckets)
10. Memory Cache Store Counters & Clerks
11. Plan Cache Hit Ratio (Normalized Calculation)
12. Expensive Cached Plans (Safe XML Retrieval)
13. Executive Summary & Plan Cache Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Review Executive Summary & Plan Cache Distribution
    2. Check Single-Use Ad-Hoc Plan Bloat (Section 2 & 3)
    3. Check Procedure Cache Efficiency & Recompiles (Section 7 & 8)
    4. Review Memory Cache Stores & Recommendations

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    PLAN CACHE MEMORY DISTRIBUTION BY OBJECT TYPE
-------------------------------------------------------------------------------
.PURPOSE
    Understand how execution plan cache memory is divided across object types.
-----------------------------------------------------------------------------*/

SELECT
    objtype AS ObjectType,
    COUNT(*) AS PlanCount,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS CacheSizeMB,
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS SingleUsePlans,
    SUM(CASE WHEN usecounts = 1 THEN CAST(size_in_bytes AS BIGINT) ELSE 0 END) / 1024 / 1024 AS SingleUseCacheMB
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY CacheSizeMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    AD-HOC PLAN CACHE BLOAT & SINGLE-USE PLANS
-------------------------------------------------------------------------------
.PURPOSE
    Measure memory wasted by unparameterized single-use ad-hoc queries.
-----------------------------------------------------------------------------*/

SELECT
    COUNT(*) AS TotalAdhocPlans,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS TotalAdhocCacheMB,
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS SingleUseAdhocPlans,
    SUM(CASE WHEN usecounts = 1 THEN CAST(size_in_bytes AS BIGINT) ELSE 0 END) / 1024 / 1024 AS SingleUseAdhocMB,
    CAST(SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS SingleUsePercentage
FROM sys.dm_exec_cached_plans
WHERE objtype = 'Adhoc';
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    TOP SINGLE-USE AD-HOC STATEMENTS CONSUMING CACHE
-------------------------------------------------------------------------------
.PURPOSE
    Identify the largest single-use ad-hoc query plans polluting the cache.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    cp.size_in_bytes / 1024 AS PlanSizeKB,
    cp.usecounts AS UseCount,
    cp.cacheobjtype AS CacheObjectType,
    st.text AS StatementText
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
WHERE cp.objtype = 'Adhoc'
  AND cp.usecounts = 1
ORDER BY cp.size_in_bytes DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    LARGEST INDIVIDUAL CACHED PLANS IN MEMORY
-------------------------------------------------------------------------------
.PURPOSE
    Identify individual execution plans consuming the most memory in cache.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    cp.objtype AS ObjectType,
    cp.usecounts AS UseCount,
    cp.size_in_bytes / 1024 AS PlanSizeKB,
    st.text AS BatchText
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
ORDER BY cp.size_in_bytes DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    MOST FREQUENTLY EXECUTED CACHED STATEMENTS
-------------------------------------------------------------------------------
.PURPOSE
    Identify high-frequency queries benefiting from plan reuse.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    qs.execution_count AS ExecutionCount,
    qs.last_execution_time AS LastExecutionTime,
    qs.total_worker_time / 1000 AS TotalCPUms,
    (qs.total_worker_time / NULLIF(qs.execution_count, 0)) / 1000.0 AS AvgCPUms,
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
ORDER BY qs.execution_count DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    TOP CPU CONSUMING CACHED STATEMENTS
-------------------------------------------------------------------------------
.PURPOSE
    Identify cached statements responsible for the highest cumulative CPU usage.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    qs.execution_count AS ExecutionCount,
    qs.total_worker_time / 1000 AS TotalCPUms,
    (qs.total_worker_time / NULLIF(qs.execution_count, 0)) / 1000.0 AS AvgCPUms,
    qs.total_elapsed_time / 1000 AS TotalDurationMs,
    qs.total_logical_reads AS TotalLogicalReads,
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
ORDER BY qs.total_worker_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 7
    STORED PROCEDURE CACHE UTILIZATION
-------------------------------------------------------------------------------
.PURPOSE
    Analyze procedure cache footprint compared to prepared plans.
-----------------------------------------------------------------------------*/

SELECT
    objtype AS ObjectType,
    COUNT(*) AS PlanCount,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS CacheSizeMB,
    AVG(usecounts) AS AvgUseCount
FROM sys.dm_exec_cached_plans
WHERE objtype IN ('Proc', 'Prepared')
GROUP BY objtype
ORDER BY CacheSizeMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    STORED PROCEDURES BY EXECUTION & RECOMPILE INDICATORS
-------------------------------------------------------------------------------
.PURPOSE
    Review procedure stats and identify frequently recompiled or newly cached routines.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    DB_NAME(database_id) AS DatabaseName,
    OBJECT_NAME(object_id, database_id) AS ProcedureName,
    cached_time AS CachedTime,
    last_execution_time AS LastExecutionTime,
    execution_count AS ExecutionCount,
    total_worker_time / 1000 AS TotalCPUms,
    (total_worker_time / NULLIF(execution_count, 0)) / 1000.0 AS AvgCPUms
FROM sys.dm_exec_procedure_stats
ORDER BY cached_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    PLAN CACHE REUSE DISTRIBUTION (USE COUNT BUCKETS)
-------------------------------------------------------------------------------
.PURPOSE
    Evaluate overall plan reuse efficiency across execution count buckets.
-----------------------------------------------------------------------------*/

SELECT
    CASE
        WHEN usecounts = 1 THEN '1 Execution (Single-Use)'
        WHEN usecounts BETWEEN 2 AND 10 THEN '2 - 10 Executions'
        WHEN usecounts BETWEEN 11 AND 100 THEN '11 - 100 Executions'
        WHEN usecounts BETWEEN 101 AND 1000 THEN '101 - 1,000 Executions'
        ELSE '> 1,000 Executions'
    END AS ReuseBucket,
    COUNT(*) AS PlanCount,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS TotalCacheMB
FROM sys.dm_exec_cached_plans
GROUP BY
    CASE
        WHEN usecounts = 1 THEN '1 Execution (Single-Use)'
        WHEN usecounts BETWEEN 2 AND 10 THEN '2 - 10 Executions'
        WHEN usecounts BETWEEN 11 AND 100 THEN '11 - 100 Executions'
        WHEN usecounts BETWEEN 101 AND 1000 THEN '101 - 1,000 Executions'
        ELSE '> 1,000 Executions'
    END
ORDER BY MIN(usecounts) ASC;
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    MEMORY CACHE STORE COUNTERS & CLERKS
-------------------------------------------------------------------------------
.PURPOSE
    Inspect memory consumed across SQLCP (Adhoc/Prepared) and OBJCP (Procedures).
-----------------------------------------------------------------------------*/

SELECT
    type AS ClerkType,
    pages_kb / 1024 AS MemoryMB,
    entries_count AS EntriesCount
FROM sys.dm_os_memory_cache_counters
WHERE type IN ('CACHESTORE_SQLCP', 'CACHESTORE_OBJCP', 'CACHESTORE_PHDR')
ORDER BY MemoryMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 11
    PLAN CACHE HIT RATIO (NORMALIZED CALCULATION)
-------------------------------------------------------------------------------
.PURPOSE
    Calculate true Plan Cache Hit Ratio by normalizing against Cache Hit Ratio Base.
-----------------------------------------------------------------------------*/

SELECT
    r.instance_name AS CacheStoreName,
    CAST(100.0 * r.cntr_value / NULLIF(b.cntr_value, 0) AS DECIMAL(5,2)) AS CacheHitRatioPercentage
FROM sys.dm_os_performance_counters r
INNER JOIN sys.dm_os_performance_counters b
    ON r.instance_name = b.instance_name
    AND b.counter_name = 'Cache Hit Ratio Base'
    AND b.object_name LIKE '%Plan Cache%'
WHERE r.counter_name = 'Cache Hit Ratio'
  AND r.object_name LIKE '%Plan Cache%';
GO

/*-----------------------------------------------------------------------------
    SECTION 12
    EXPENSIVE CACHED PLANS (SAFE XML RETRIEVAL)
-------------------------------------------------------------------------------
.PURPOSE
    Safely retrieve execution plans for top 5 CPU consuming cached queries.
-----------------------------------------------------------------------------*/

SELECT TOP (5)
    qs.total_worker_time / 1000 AS TotalCPUms,
    qs.execution_count AS ExecutionCount,
    SUBSTRING(
        st.text,
        (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
         END - qs.statement_start_offset) / 2) + 1
    ) AS StatementText,
    qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.total_worker_time DESC
OPTION (MAXDOP 1);
GO

/*-----------------------------------------------------------------------------
    SECTION 13
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    High-level Plan Cache health dashboard.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_cached_plans) AS TotalCachedPlans,
    (SELECT SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 FROM sys.dm_exec_cached_plans) AS TotalCacheMB,
    (SELECT COUNT(*) FROM sys.dm_exec_cached_plans WHERE objtype = 'Adhoc' AND usecounts = 1) AS SingleUseAdhocPlans,
    (SELECT SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 FROM sys.dm_exec_cached_plans WHERE objtype = 'Adhoc' AND usecounts = 1) AS SingleUseAdhocMB,
    (SELECT value_in_use FROM sys.configurations WHERE name = 'optimize for ad hoc workloads') AS OptimizeForAdHocWorkloadsSetting;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
PLAN CACHE SYMPTOM                  ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
Single-Use Adhoc Plans > 10,000     --> Enable 'optimize for ad hoc workloads'
Ad-Hoc Cache MB > Buffer Pool       --> Address unparameterized client application SQL
Frequent Procedure Recompiles       --> Inspect procedure stats and recompile options
Low Cache Hit Ratio (<80%)          --> Investigate dynamic SQL strings with literal parameters
******************************************************************************/


    DB_NAME(database_id) AS DatabaseName,

    OBJECT_NAME(object_id, database_id) AS ObjectName,

    cached_time,

    last_execution_time,

    execution_count

FROM sys.dm_exec_procedure_stats

ORDER BY cached_time DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 10
-- PLAN REUSE ANALYSIS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Evaluate cache effectiveness.
--
--------------------------------------------------------------------------------

SELECT

    usecounts,

    COUNT(*) AS PlanCount

FROM sys.dm_exec_cached_plans

GROUP BY usecounts

ORDER BY usecounts;

GO

--------------------------------------------------------------------------------
-- SECTION 11
-- CACHE STORE DISTRIBUTION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Analyze cache stores.
--
--------------------------------------------------------------------------------

SELECT

    type,

    pages_kb / 1024 AS MB,

    entries_count

FROM sys.dm_os_memory_cache_counters

ORDER BY MB DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 12
-- MEMORY CLERKS RELATED TO PLAN CACHE
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review memory allocated to cache components.
--
--------------------------------------------------------------------------------

SELECT

    type,

    SUM(pages_kb)/1024 AS MB

FROM sys.dm_os_memory_clerks

WHERE type LIKE '%CACHE%'

GROUP BY type

ORDER BY MB DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 13
-- BUFFER CACHE VS PLAN CACHE
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Compare cache consumption.
--
--------------------------------------------------------------------------------

SELECT

    type,

    SUM(pages_kb)/1024 AS MB

FROM sys.dm_os_memory_clerks

WHERE type IN
(
    'MEMORYCLERK_SQLBUFFERPOOL',
    'CACHESTORE_SQLCP',
    'CACHESTORE_OBJCP'
)

GROUP BY type

ORDER BY MB DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 14
-- PLAN CACHE HIT RATIO
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Evaluate cache efficiency.
--
--
-- HEALTHY
--
--     Generally above 90%.
--
--------------------------------------------------------------------------------

SELECT

    counter_name,

    cntr_value

FROM sys.dm_os_performance_counters

WHERE counter_name LIKE '%Cache Hit Ratio%'
ORDER BY counter_name;

GO

--------------------------------------------------------------------------------
-- SECTION 15
-- ADHOC PLANS USING SIGNIFICANT MEMORY
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify largest Adhoc plans.
--
--------------------------------------------------------------------------------

SELECT TOP 25

    cp.usecounts,

    cp.size_in_bytes/1024 AS PlanKB,

    st.text

FROM sys.dm_exec_cached_plans cp

CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st

WHERE cp.objtype = 'Adhoc'

ORDER BY cp.size_in_bytes DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 16
-- UNUSED LARGE PLANS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Find plans consuming memory but rarely reused.
--
--------------------------------------------------------------------------------

SELECT TOP 25

    cp.usecounts,

    cp.size_in_bytes/1024 AS PlanKB,

    cp.objtype,

    st.text

FROM sys.dm_exec_cached_plans cp

CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st

WHERE cp.usecounts <= 1

ORDER BY cp.size_in_bytes DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 17
-- EXECUTION PLAN REVIEW
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Retrieve execution plans for expensive queries.
--
--------------------------------------------------------------------------------

SELECT TOP 20

    qs.total_worker_time / 1000 AS TotalCPUms,

    qs.execution_count,

    st.text,

    qp.query_plan

FROM sys.dm_exec_query_stats qs

CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st

CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp

ORDER BY qs.total_worker_time DESC

OPTION (MAXDOP 1);

GO

--------------------------------------------------------------------------------
-- SECTION 18
-- TRIAGE INDICATORS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     High-level cache health assessment.
--
--------------------------------------------------------------------------------

SELECT

    CASE
        WHEN
        (
            SELECT COUNT(*)
            FROM sys.dm_exec_cached_plans
            WHERE objtype = 'Adhoc'
        ) >
        (
            SELECT COUNT(*)
            FROM sys.dm_exec_cached_plans
        ) * 0.50
        THEN 'YES'
        ELSE 'NO'
    END AS AdhocPollutionDetected,

    (
        SELECT COUNT(*)
        FROM sys.dm_exec_cached_plans
        WHERE usecounts = 1
    ) AS SingleUsePlans,

    (
        SELECT SUM(size_in_bytes)/1024/1024
        FROM sys.dm_exec_cached_plans
    ) AS TotalPlanCacheMB;

GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

PLAN CACHE POLLUTION

INDICATORS

    High Adhoc plan count
    Large Adhoc cache footprint
    Many Single-Use plans

REVIEW

    Sections 3, 4, 15, 16

------------------------------------------------------------------------------
MEMORY CONSUMPTION ISSUE

INDICATORS

    Large Plan Cache MB
    Cache growing aggressively

REVIEW

    Sections 2, 11, 12, 13

------------------------------------------------------------------------------
POOR PLAN REUSE

INDICATORS

    Single-use plans
    Low usecounts
    Frequent recompilations

REVIEW

    Sections 4, 9, 10

------------------------------------------------------------------------------
EXPENSIVE CACHED QUERIES

INDICATORS

    High CPU
    Long duration
    High logical reads

REVIEW

    Sections 7, 17

------------------------------------------------------------------------------
PARAMETERIZATION ISSUE

INDICATORS

    Excessive Adhoc plans
    Similar SQL statements
    Low plan reuse

REVIEW

    Sections 3, 4, 10, 15

------------------------------------------------------------------------------
CACHE EFFICIENCY ISSUE

INDICATORS

    Low Cache Hit Ratio
    High compilation activity

REVIEW

    Sections 10, 14

******************************************************************************
END OF FILE
******************************************************************************/