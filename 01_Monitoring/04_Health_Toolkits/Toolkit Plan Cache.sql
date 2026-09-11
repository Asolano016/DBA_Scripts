/******************************************************************************
SQL SERVER PLAN CACHE HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

PURPOSE

This toolkit helps identify:

1. Plan cache memory consumption
2. Adhoc plan cache pollution
3. Single-use plans
4. Stored procedure cache efficiency
5. Recompile activity
6. Large execution plans
7. Frequently executed plans
8. Expensive cached queries
9. Plan cache fragmentation patterns
10. Overall plan cache health

RECOMMENDED TROUBLESHOOTING FLOW

    1. Executive Summary
    2. Plan Cache Memory Distribution
    3. Adhoc Plan Analysis
    4. Single-Use Plans
    5. Largest Cached Plans
    6. Most Executed Cached Plans
    7. Most Expensive Cached Plans
    8. Procedure Cache Analysis
    9. Recompile Activity
    10. Plan Reuse Analysis
    11. Cache Stores
    12. Memory Clerks
    13. Cache Hit Ratios
    14. Triage Indicators

******************************************************************************/

--------------------------------------------------------------------------------
-- SECTION 1
-- EXECUTIVE SUMMARY
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Quick plan cache health overview.
--
-- HEALTHY
--
--     Low Adhoc percentage.
--     High plan reuse.
--     Limited single-use plans.
--
-- INVESTIGATE
--
--     Excessive Adhoc plans.
--     Large cache usage.
--     Many single-use plans.
--
--------------------------------------------------------------------------------

SELECT

    GETDATE() AS CaptureTime,

    (SELECT COUNT(*)
     FROM sys.dm_exec_cached_plans) AS TotalPlans,

    (SELECT COUNT(*)
     FROM sys.dm_exec_cached_plans
     WHERE objtype = 'Adhoc') AS AdhocPlans,

    (SELECT COUNT(*)
     FROM sys.dm_exec_cached_plans
     WHERE usecounts = 1) AS SingleUsePlans,

    (SELECT SUM(size_in_bytes)/1024/1024
     FROM sys.dm_exec_cached_plans) AS TotalCacheMB;

GO

--------------------------------------------------------------------------------
-- SECTION 2
-- PLAN CACHE MEMORY DISTRIBUTION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Understand cache memory consumption by object type.
--
--------------------------------------------------------------------------------

SELECT

    objtype,

    COUNT(*) AS Plans,

    SUM(size_in_bytes)/1024/1024 AS CacheMB

FROM sys.dm_exec_cached_plans

GROUP BY objtype

ORDER BY CacheMB DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 3
-- ADHOC PLAN ANALYSIS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify Adhoc cache pollution.
--
-- WHY THIS MATTERS
--
--     Excessive Adhoc plans:
--
--         Waste memory
--         Increase compilation overhead
--         Reduce cache efficiency
--
--------------------------------------------------------------------------------

SELECT

    COUNT(*) AS AdhocPlans,

    SUM(size_in_bytes)/1024/1024 AS AdhocCacheMB

FROM sys.dm_exec_cached_plans

WHERE objtype = 'Adhoc';

GO

--------------------------------------------------------------------------------
-- SECTION 4
-- SINGLE-USE PLAN ANALYSIS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify plans compiled once and never reused.
--
-- WARNING
--
--     High counts may indicate
--     poor parameterization.
--
--------------------------------------------------------------------------------

SELECT

    COUNT(*) AS SingleUsePlans,

    SUM(size_in_bytes)/1024/1024 AS SingleUseCacheMB

FROM sys.dm_exec_cached_plans

WHERE usecounts = 1;

GO

--------------------------------------------------------------------------------
-- SECTION 5
-- LARGEST CACHED PLANS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify plans consuming the most memory.
--
--------------------------------------------------------------------------------

SELECT TOP 25

    cp.usecounts,

    cp.objtype,

    cp.size_in_bytes / 1024 AS PlanKB,

    st.text

FROM sys.dm_exec_cached_plans cp

CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st

ORDER BY cp.size_in_bytes DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 6
-- MOST EXECUTED CACHED QUERIES
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify heavily reused plans.
--
--------------------------------------------------------------------------------

SELECT TOP 25

    qs.execution_count,

    qs.last_execution_time,

    st.text

FROM sys.dm_exec_query_stats qs

CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st

ORDER BY qs.execution_count DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 7
-- MOST EXPENSIVE CACHED QUERIES
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify cached plans contributing most workload.
--
--------------------------------------------------------------------------------

SELECT TOP 25

    qs.execution_count,

    qs.total_worker_time / 1000 AS TotalCPUms,

    qs.total_elapsed_time / 1000 AS TotalDurationMS,

    qs.total_logical_reads,

    st.text

FROM sys.dm_exec_query_stats qs

CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st

ORDER BY qs.total_worker_time DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 8
-- PROCEDURE CACHE ANALYSIS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review procedure cache utilization.
--
--------------------------------------------------------------------------------

SELECT

    objtype,

    COUNT(*) AS Plans,

    SUM(size_in_bytes)/1024/1024 AS CacheMB

FROM sys.dm_exec_cached_plans

WHERE objtype IN
(
    'Proc',
    'Prepared'
)

GROUP BY objtype

ORDER BY CacheMB DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 9
-- RECOMPILE ANALYSIS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify procedures experiencing recompiles.
--
--------------------------------------------------------------------------------

SELECT TOP 50

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