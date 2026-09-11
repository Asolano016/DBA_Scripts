/******************************************************************************
SQL SERVER QUERY PERFORMANCE HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

PURPOSE

This toolkit provides a structured approach for identifying
poorly performing queries and tuning opportunities.

The goal is to answer:

    • Which queries are slow?
    • Which queries consume the most CPU?
    • Which queries generate excessive reads?
    • Which queries generate excessive writes?
    • Which queries request excessive memory?
    • Are indexes missing?
    • Is parameter sniffing suspected?
    • Have execution plans regressed?

AREAS COVERED

1. Active Requests
2. Top Duration Queries
3. Top CPU Queries
4. Top Read Queries
5. Top Write Queries
6. Memory Grant Analysis
7. Missing Index Impact
8. Parameter Sniffing Indicators
9. Query Store Analysis
10. Executive Summary

WHEN TO USE THIS TOOLKIT

Use this toolkit when:

    • Specific queries are slow
    • Application performance is degraded
    • CPU consumption is elevated
    • Excessive reads are detected
    • Memory Grant issues are suspected
    • Query tuning opportunities are being investigated

RECOMMENDED TROUBLESHOOTING FLOW

Step 1
-------
Review Executive Summary

Step 2
-------
Identify active problematic requests

Step 3
-------
Review CPU, Reads and Duration

Step 4
-------
Analyze Memory Grants

Step 5
-------
Review Missing Indexes

Step 6
-------
Review Query Store information

******************************************************************************/




/*-------------------------------------------------------------------------------
    SECTION 1
    ACTIVE REQUESTS
-------------------------------------------------------------------------------

.PURPOSE

    Review currently executing requests.

.WHY THIS MATTERS

    Active requests frequently reveal ongoing performance issues.

.KEY METRICS

    cpu_time

    logical_reads

    writes

    total_elapsed_time

.HEALTHY

    Queries complete within expected timeframes.

.WARNING

    Long running requests.

.POSSIBLE CAUSES

    Blocking.
    Excessive reads.
    Missing indexes.
    Poor execution plans.

.NEXT ACTIONS

    Review execution plans.
    Review Sections 2 through 6.

-------------------------------------------------------------------------------*/

SELECT
    r.session_id,
    r.status,
    r.command,
    r.cpu_time,
    r.logical_reads,
    r.writes,
    r.total_elapsed_time,
    r.wait_type,
    DB_NAME(r.database_id) AS DatabaseName,
    t.text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id > 50
ORDER BY r.total_elapsed_time DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 2
    TOP DURATION QUERIES
-------------------------------------------------------------------------------

.PURPOSE

    Identify queries with the highest average duration.

.WHY THIS MATTERS

    Slow queries are often responsible for application complaints.

.KEY METRICS

    AvgDurationMs

    TotalDurationMs

    ExecutionCount

.HEALTHY

    Query duration aligns with workload expectations.

.WARNING

    Extremely high average duration.

.POSSIBLE CAUSES

    Blocking.
    Memory pressure.
    Storage latency.
    Poor execution plans.

.NEXT ACTIONS

    Review execution plans.
    Review Wait Statistics Toolkit.

-------------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_elapsed_time / 1000 AS TotalDurationMs,
    (qs.total_elapsed_time / qs.execution_count) / 1000 AS AvgDurationMs,
    st.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY AvgDurationMs DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 3
    TOP CPU QUERIES
-------------------------------------------------------------------------------

.PURPOSE

    Identify the highest CPU consuming queries.

.WHY THIS MATTERS

    A small number of queries often account for most CPU consumption.

.KEY METRICS

    TotalCPUms

    AvgCPUms

    ExecutionCount

.HEALTHY

    CPU usage distributed across workload.

.WARNING

    Small number of queries dominate CPU consumption.

.POSSIBLE CAUSES

    Missing indexes.
    Large scans.
    Inefficient plans.
    Scalar UDF usage.

.NEXT ACTIONS

    Review execution plans.
    Review CPU Toolkit.

-------------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_worker_time / 1000 AS TotalCPUms,
    (qs.total_worker_time / qs.execution_count) / 1000 AS AvgCPUms,
    st.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_worker_time DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 4
    TOP READ QUERIES
-------------------------------------------------------------------------------

.PURPOSE

    Identify queries generating the most logical reads.

.WHY THIS MATTERS

    Excessive reads increase CPU, IO and memory pressure.

.KEY METRICS

    TotalLogicalReads

    AvgLogicalReads

.HEALTHY

    Reads align with data volume expectations.

.WARNING

    Excessive logical reads.

.POSSIBLE CAUSES

    Table scans.
    Missing indexes.
    Poor filtering predicates.

.NEXT ACTIONS

    Review execution plans.
    Review Missing Index section.

-------------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_logical_reads AS TotalLogicalReads,
    qs.total_logical_reads / qs.execution_count AS AvgLogicalReads,
    st.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_logical_reads DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 5
    TOP WRITE QUERIES
-------------------------------------------------------------------------------

.PURPOSE

    Identify write-intensive queries.

.WHY THIS MATTERS

    High write activity can impact transaction throughput.

.KEY METRICS

    TotalLogicalWrites

    AvgLogicalWrites

.HEALTHY

    Write activity aligns with business workload.

.WARNING

    Queries generating excessive writes.

.POSSIBLE CAUSES

    Batch updates.
    ETL workloads.
    Index maintenance.

.NEXT ACTIONS

    Review workload patterns.
    Review transaction design.

-------------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_logical_writes AS TotalLogicalWrites,
    qs.total_logical_writes / qs.execution_count AS AvgLogicalWrites,
    st.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_logical_writes DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 6
    MEMORY GRANT ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Identify queries requesting large memory grants.

.WHY THIS MATTERS

    Excessive grants reduce concurrency and can delay query execution.

.KEY METRICS

    MaxGrantMB

    MaxUsedGrantMB

.HEALTHY

    Grant size close to actual usage.

.WARNING

    MaxGrantMB significantly exceeds MaxUsedGrantMB.

.POSSIBLE CAUSES

    Poor cardinality estimates.
    Outdated statistics.
    Parameter sniffing.

.NEXT ACTIONS

    Review execution plans.
    Review Memory Toolkit.

-------------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.max_grant_kb / 1024 AS MaxGrantMB,
    qs.max_used_grant_kb / 1024 AS MaxUsedGrantMB,
    qs.execution_count,
    st.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.max_grant_kb DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 7
    MISSING INDEX IMPACT
-------------------------------------------------------------------------------

.PURPOSE

    Review high-impact missing index recommendations.

.WHY THIS MATTERS

    Missing indexes commonly cause excessive reads and CPU usage.

.KEY METRICS

    avg_user_impact

    user_seeks

.HEALTHY

    Few high-impact missing indexes.

.WARNING

    High impact ratings and user seek counts.

.POSSIBLE CAUSES

    Untuned workload.
    Recently deployed functionality.

.NEXT ACTIONS

    Validate recommendations before implementation.

-------------------------------------------------------------------------------*/

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




/*-------------------------------------------------------------------------------
    SECTION 8
    PARAMETER SNIFFING INDICATORS
-------------------------------------------------------------------------------

.PURPOSE

    Identify queries that may suffer from parameter sniffing.

.WHY THIS MATTERS

    Queries may perform differently depending on parameter values.

.KEY METRICS

    MinElapsedTime

    MaxElapsedTime

    MinWorkerTime

    MaxWorkerTime

.HEALTHY

    Relatively consistent execution metrics.

.WARNING

    Large variance between minimum and maximum values.

.POSSIBLE CAUSES

    Parameter sniffing.
    Data skew.
    Cardinality estimation issues.

.NEXT ACTIONS

    Review execution plans.
    Compare runtime parameters.

-------------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.min_elapsed_time,
    qs.max_elapsed_time,
    qs.min_worker_time,
    qs.max_worker_time,
    st.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY (qs.max_elapsed_time - qs.min_elapsed_time) DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 9
    QUERY STORE ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Identify expensive queries captured by Query Store.

.WHY THIS MATTERS

    Query Store allows identification of regressions and performance trends.

.KEY METRICS

    AvgDuration

    AvgCPUTime

.HEALTHY

    Stable query performance.

.WARNING

    Significant duration or CPU increases.

.POSSIBLE CAUSES

    Plan regression.
    Statistics changes.
    Data growth.

.NEXT ACTIONS

    Consider forcing a known good plan when appropriate.

-------------------------------------------------------------------------------*/

IF EXISTS
(
    SELECT 1
    FROM sys.objects
    WHERE name = 'query_store_query'
)
BEGIN

    SELECT TOP (20)
        qsq.query_id,
        qsp.plan_id,
        rs.avg_duration,
        rs.avg_cpu_time
    FROM sys.query_store_query qsq
    JOIN sys.query_store_plan qsp
        ON qsq.query_id = qsp.query_id
    JOIN sys.query_store_runtime_stats rs
        ON qsp.plan_id = rs.plan_id
    ORDER BY rs.avg_duration DESC;

END

GO




/*-------------------------------------------------------------------------------
    SECTION 10
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------

.PURPOSE

    Provide a quick query performance assessment.

.HEALTHY ENVIRONMENT

    No long running active requests.

    CPU usage distributed across workload.

    Logical reads remain reasonable.

    Memory grants close to actual usage.

    Few high-impact missing indexes.

.INVESTIGATE

    High duration queries.

    High CPU consumers.

    Excessive logical reads.

    Large memory grants.

    Parameter sniffing indicators.

.NEXT ACTIONS

    Active Workload:
        Review Section 1

    Duration:
        Review Section 2

    CPU:
        Review Section 3

    Reads:
        Review Section 4

    Memory Grants:
        Review Section 6

    Missing Indexes:
        Review Section 7

-------------------------------------------------------------------------------*/

SELECT

    (SELECT COUNT(*)
     FROM sys.dm_exec_requests
     WHERE session_id > 50) AS ActiveRequests,

    (SELECT COUNT(*)
     FROM sys.dm_db_missing_index_details) AS MissingIndexes,

    (SELECT COUNT(*)
     FROM sys.dm_exec_cached_plans) AS CachedPlans,

    (SELECT COUNT(*)
     FROM sys.dm_exec_query_stats) AS CachedQueries;

GO




/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

SLOW QUERY ISSUE

INDICATORS

    High AvgDurationMs

REVIEW

    Section 2

------------------------------------------------------------------------------
CPU ISSUE

INDICATORS

    High TotalCPUms

REVIEW

    Section 3

    Health CPU Toolkit

------------------------------------------------------------------------------
READ ISSUE

INDICATORS

    High Logical Reads

REVIEW

    Section 4

    Health IO Toolkit

------------------------------------------------------------------------------
WRITE ISSUE

INDICATORS

    High Logical Writes

REVIEW

    Section 5

------------------------------------------------------------------------------
MEMORY GRANT ISSUE

INDICATORS

    MaxGrantMB >> MaxUsedGrantMB

REVIEW

    Section 6

    Health Memory Toolkit

------------------------------------------------------------------------------
INDEX ISSUE

INDICATORS

    High avg_user_impact

REVIEW

    Section 7

------------------------------------------------------------------------------
PARAMETER SNIFFING ISSUE

INDICATORS

    Large runtime variance

REVIEW

    Section 8

------------------------------------------------------------------------------
PLAN REGRESSION ISSUE

INDICATORS

    Increased duration after plan change

REVIEW

    Section 9

******************************************************************************
END OF QUERY PERFORMANCE HEALTH CHECK
******************************************************************************/