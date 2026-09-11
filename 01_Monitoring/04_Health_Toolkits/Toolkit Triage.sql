/******************************************************************************
SQL SERVER QUERY PERFORMANCE HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit helps identify:

1. Expensive queries
2. CPU bottlenecks
3. Excessive I/O activity
4. Blocking
5. Wait-related performance issues
6. Missing indexes
7. Plan cache inefficiencies
8. Parallelism issues
9. TempDB pressure
10. Overall query performance health

RECOMMENDED TROUBLESHOOTING FLOW

    1. Executive Summary
    2. Active Requests
    3. Wait Statistics
    4. Blocking Analysis
    5. Top CPU Queries
    6. Top Logical Read Queries
    7. Missing Indexes
    8. Parallelism Analysis
    9. TempDB Usage

******************************************************************************/

/*-------------------------------------------------------------------------------
    SECTION 1
    CURRENTLY RUNNING REQUESTS
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Show active user requests executing right now.
--
-- WHY THIS MATTERS
--     During incidents this is typically the first place to look.
--
-- WHAT TO LOOK FOR
--
--     Long-running sessions
--     Suspended status
--     High CPU consumers
--     Blocking sessions
--
-- HEALTHY
--
--     Few active requests.
--     Low wait times.
--
-- WARNING
--
--     Requests running for hours.
--     High wait_time values.
--     Multiple blocked sessions.
--
-------------------------------------------------------------------------------*/

SELECT
    r.session_id,
    r.status,
    r.command,
    r.cpu_time,
    r.total_elapsed_time,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS DatabaseName,
    t.text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id > 50
ORDER BY r.total_elapsed_time DESC;

GO

/*-------------------------------------------------------------------------------
-- SECTION 2
-- TOP CPU CONSUMING QUERIES
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Identify queries consuming most CPU historically.
--
-- WHY THIS MATTERS
--
--     High CPU is often caused by:
--
--         Missing indexes
--         Large scans
--         Poor execution plans
--         Scalar functions
--
-- INVESTIGATE
--
--     Queries with large AvgCPUms.
--
-------------------------------------------------------------------------------*/

SELECT TOP 20
    qs.execution_count,
    (qs.total_worker_time / qs.execution_count) / 1000 AS AvgCPUms,
    qs.total_worker_time / 1000 AS TotalCPUms,
    SUBSTRING
    (
        st.text,
        (qs.statement_start_offset / 2) + 1,
        (
            (
                CASE qs.statement_end_offset
                    WHEN -1 THEN DATALENGTH(st.text)
                    ELSE qs.statement_end_offset
                END
                - qs.statement_start_offset
            ) / 2
        ) + 1
    ) AS QueryText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY TotalCPUms DESC;

GO

/*-------------------------------------------------------------------------------
-- SECTION 3
-- TOP LOGICAL READ CONSUMERS
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Identify queries reading the most data.
--
-- WHY THIS MATTERS
--
--     High logical reads usually indicate:
--
--         Table scans
--         Missing indexes
--         Poor predicates
--
-- INVESTIGATE
--
--     Queries with very high AvgLogicalReads.
--
-------------------------------------------------------------------------------*/

SELECT TOP 20
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count AS AvgLogicalReads,
    qs.total_logical_reads AS TotalLogicalReads,
    SUBSTRING
    (
        st.text,
        (qs.statement_start_offset / 2) + 1,
        (
            (
                CASE qs.statement_end_offset
                    WHEN -1 THEN DATALENGTH(st.text)
                    ELSE qs.statement_end_offset
                END
                - qs.statement_start_offset
            ) / 2
        ) + 1
    ) AS QueryText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY TotalLogicalReads DESC;

GO

-------------------------------------------------------------------------------
-- SECTION 4
-- TOP DURATION QUERIES
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Identify queries with highest average runtime.
--
-- WHY THIS MATTERS
--
--     Long duration may indicate:
--
--         Blocking
--         I/O waits
--         CPU pressure
--         Memory grant waits
--
-------------------------------------------------------------------------------

SELECT TOP 20
    qs.execution_count,
    (qs.total_elapsed_time / qs.execution_count) / 1000 AS AvgDurationMs,
    SUBSTRING
    (
        st.text,
        (qs.statement_start_offset / 2) + 1,
        (
            (
                CASE qs.statement_end_offset
                    WHEN -1 THEN DATALENGTH(st.text)
                    ELSE qs.statement_end_offset
                END
                - qs.statement_start_offset
            ) / 2
        ) + 1
    ) AS QueryText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY AvgDurationMs DESC;

GO

-------------------------------------------------------------------------------
-- SECTION 5
-- BLOCKING ANALYSIS
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Identify blocking chains.
--
-- HEALTHY
--
--     No rows returned.
--
-- WARNING
--
--     Blocking chains.
--     Same blocking_session_id repeated.
--
-------------------------------------------------------------------------------

SELECT
    session_id,
    blocking_session_id,
    wait_type,
    wait_time,
    status,
    command
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0
ORDER BY blocking_session_id;

GO

-------------------------------------------------------------------------------
-- SECTION 6
-- TOP WAIT STATISTICS
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Identify where SQL Server spends time waiting.
--
-- COMMON WAITS
--
-- CXPACKET / CXCONSUMER
--     Parallelism.
--
-- PAGEIOLATCH%
--     Storage latency.
--
-- SOS_SCHEDULER_YIELD
--     CPU pressure.
--
-- LCK_M_%
--     Blocking.
--
-- ASYNC_NETWORK_IO
--     Slow client consumption.
--
-------------------------------------------------------------------------------

SELECT TOP 25
    wait_type,
    wait_time_ms,
    signal_wait_time_ms,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE '%SLEEP%'
ORDER BY wait_time_ms DESC;

GO

-------------------------------------------------------------------------------
-- SECTION 7
-- MISSING INDEXES
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Identify potentially beneficial indexes.
--
-- WARNING
--
--     Not every recommendation should be created.
--
-- ALWAYS REVIEW:
--
--     Existing indexes.
--     Duplicate indexes.
--     Write workload impact.
--
-------------------------------------------------------------------------------

SELECT
    migs.avg_user_impact,
    migs.user_seeks,
    mid.statement,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig
    ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs
    ON mig.index_group_handle = migs.group_handle
ORDER BY migs.avg_user_impact DESC;

GO

-------------------------------------------------------------------------------
-- SECTION 8
-- INDEX USAGE ANALYSIS
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Identify unused indexes.
--
-- WHY THIS MATTERS
--
--     Unused indexes:
--
--         Consume storage
--         Increase maintenance cost
--         Slow writes
--
-------------------------------------------------------------------------------

SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    ISNULL(us.user_seeks,0) AS Seeks,
    ISNULL(us.user_scans,0) AS Scans,
    ISNULL(us.user_lookups,0) AS Lookups,
    ISNULL(us.user_updates,0) AS Updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
    ON us.object_id = i.object_id
    AND us.index_id = i.index_id
    AND us.database_id = DB_ID()
WHERE i.index_id > 0
ORDER BY Updates DESC;

GO

-------------------------------------------------------------------------------
-- SECTION 9
-- PARALLELISM ANALYSIS
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Review server-wide parallelism settings.
--
-- REVIEW
--
--     max degree of parallelism
--     cost threshold for parallelism
--
-- COMMON GUIDELINE
--
--     Cost Threshold = 5 is often too low.
--
-------------------------------------------------------------------------------

SELECT
    name,
    value_in_use
FROM sys.configurations
WHERE name IN
(
    'max degree of parallelism',
    'cost threshold for parallelism'
);

GO

-------------------------------------------------------------------------------
-- SECTION 10
-- TEMPDB USAGE
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Identify sessions consuming TempDB.
--
-- HIGH TEMPDB USAGE MAY INDICATE
--
--     Sorts
--     Hash operations
--     Version store activity
--     Poor query plans
--
-------------------------------------------------------------------------------

SELECT
    session_id,
    internal_objects_alloc_page_count * 8 / 1024 AS InternalMB,
    user_objects_alloc_page_count * 8 / 1024 AS UserMB
FROM sys.dm_db_session_space_usage
ORDER BY InternalMB DESC;

GO

-------------------------------------------------------------------------------
-- SECTION 11
-- PLAN CACHE DISTRIBUTION
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Understand how plan cache memory is used.
--
-- WARNING
--
--     Excessive Adhoc cache may indicate plan cache pollution.
--
-------------------------------------------------------------------------------

SELECT
    objtype,
    COUNT(*) AS Plans,
    SUM(size_in_bytes)/1024/1024 AS CacheMB
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY CacheMB DESC;

GO

-------------------------------------------------------------------------------
-- SECTION 12
-- EXECUTION PLANS FOR EXPENSIVE ACTIVE REQUESTS
-------------------------------------------------------------------------------
--
-- PURPOSE
--     Retrieve execution plans for currently running requests.
--
-- WHEN TO USE
--
--     High CPU incidents.
--     Blocking incidents.
--     Long-running queries.
--
-- LOOK FOR
--
--     Table Scans
--     Index Scans
--     Sorts
--     Hash Match
--     Parallelism operators
--
-------------------------------------------------------------------------------

SELECT
    r.session_id,
    r.cpu_time,
    r.total_elapsed_time,
    t.text,
    qp.query_plan
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) qp
WHERE r.session_id > 50
OPTION (MAXDOP 1);

GO

-------------------------------------------------------------------------------
-- SECTION 13
-- EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
--
-- HEALTHY ENVIRONMENT
--
--     No blocking
--     Low waits
--     Balanced CPU usage
--     Minimal TempDB pressure
--     Reasonable logical reads
--
-- INVESTIGATE
--
--     High PAGEIOLATCH waits
--     High CXPACKET waits
--     Heavy blocking
--     Large scans
--     Expensive CPU consumers
--
-------------------------------------------------------------------------------

SELECT
    (SELECT COUNT(*)
     FROM sys.dm_exec_requests
     WHERE blocking_session_id <> 0) AS BlockingSessions,

    (SELECT COUNT(*)
     FROM sys.dm_exec_requests
     WHERE session_id > 50) AS ActiveRequests,

    (SELECT COUNT(*)
     FROM sys.dm_db_missing_index_details) AS MissingIndexRecommendations,

    (SELECT COUNT(*)
     FROM sys.dm_exec_cached_plans
     WHERE objtype = 'Adhoc') AS AdhocPlans;

GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

CPU ISSUE

INDICATORS

    High SOS_SCHEDULER_YIELD waits
    High CPU consumers identified

REVIEW

    Sections 2, 6, 12

------------------------------------------------------------------------------
I/O ISSUE

INDICATORS

    PAGEIOLATCH waits
    High logical reads

REVIEW

    Sections 3, 6, 7

------------------------------------------------------------------------------
BLOCKING ISSUE

INDICATORS

    Blocking chains
    LCK_M_% waits

REVIEW

    Sections 1, 5, 6

------------------------------------------------------------------------------
INDEXING ISSUE

INDICATORS

    High reads
    Missing index recommendations

REVIEW

    Sections 3, 7, 8

------------------------------------------------------------------------------
PARALLELISM ISSUE

INDICATORS

    CXPACKET
    CXCONSUMER

REVIEW

    Sections 6, 9

------------------------------------------------------------------------------
TEMPDB ISSUE

INDICATORS

    Large TempDB consumers
    Sort-heavy workload

REVIEW

    Section 10

******************************************************************************
END OF FILE
******************************************************************************/