/******************************************************************************
SQL SERVER QUERY PERFORMANCE HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a multidimensional approach for identifying slow queries,
CPU/IO/Memory intensive statements, parameter sniffing candidates, execution plan
regressions, and Query Store insights.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Active Executing Requests (Statement Level)
2. Top Queries by Average & Total Elapsed Duration
3. Top Queries by CPU Worker Time
4. Top Queries by Logical Reads (Memory & Storage Churn)
5. Top Queries by Logical Writes
6. Queries with High Memory Grants & Overestimations
7. High-Impact Missing Index Recommendations
8. Parameter Sniffing Candidates (High Runtime Variance)
9. Query Store Overview & Database Analysis
10. Execution Plans for Top Regressed Queries
11. Executive Summary & Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Executive Summary & Active Requests
    2. Top CPU / Read / Duration Statements
    3. Memory Grants & Parameter Sniffing
    4. Query Store Analysis

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    ACTIVE EXECUTING REQUESTS (STATEMENT LEVEL)
-------------------------------------------------------------------------------
.PURPOSE
    Show active user queries currently executing in the engine.
-----------------------------------------------------------------------------*/

SELECT
    r.session_id,
    r.status,
    r.command,
    r.cpu_time AS CPUTimeMs,
    r.total_elapsed_time AS ElapsedTimeMs,
    r.logical_reads AS LogicalReads,
    r.writes AS Writes,
    r.wait_type,
    r.wait_time AS WaitTimeMs,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS DatabaseName,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS StatementText
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.session_id > 50
  AND r.session_id <> @@SPID
ORDER BY r.total_elapsed_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    TOP QUERIES BY AVERAGE & TOTAL ELAPSED DURATION
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries taking the longest time to execute on average.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    (qs.total_elapsed_time / NULLIF(qs.execution_count, 0)) / 1000 AS AvgDurationMs,
    qs.total_elapsed_time / 1000 AS TotalDurationMs,
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
ORDER BY AvgDurationMs DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    TOP QUERIES BY CPU WORKER TIME
-------------------------------------------------------------------------------
.PURPOSE
    Identify statements consuming the most cumulative CPU time.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_worker_time / 1000 AS TotalCPUms,
    (qs.total_worker_time / NULLIF(qs.execution_count, 0)) / 1000 AS AvgCPUms,
    qs.total_logical_reads AS TotalLogicalReads,
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
ORDER BY qs.total_worker_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    TOP QUERIES BY LOGICAL READS
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries reading the most data pages from memory and storage.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_logical_reads AS TotalLogicalReads,
    (qs.total_logical_reads / NULLIF(qs.execution_count, 0)) AS AvgLogicalReads,
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
ORDER BY qs.total_logical_reads DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    TOP QUERIES BY LOGICAL WRITES
-------------------------------------------------------------------------------
.PURPOSE
    Identify statements performing heavy data modifications.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_logical_writes AS TotalLogicalWrites,
    (qs.total_logical_writes / NULLIF(qs.execution_count, 0)) AS AvgLogicalWrites,
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
ORDER BY qs.total_logical_writes DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    QUERIES WITH HIGH MEMORY GRANTS & OVERESTIMATIONS
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries requesting large memory grants and compare against actual usage.
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
    SECTION 7
    HIGH-IMPACT MISSING INDEX RECOMMENDATIONS
-------------------------------------------------------------------------------
.PURPOSE
    Review missing index recommendations prioritized by user impact and seeks.
-----------------------------------------------------------------------------*/

SELECT TOP (15)
    CAST(migs.avg_user_impact AS DECIMAL(5,2)) AS AvgUserImpactPct,
    migs.user_seeks AS UserSeeks,
    migs.user_scans AS UserScans,
    DB_NAME(mid.database_id) AS DatabaseName,
    mid.statement AS TableName,
    mid.equality_columns AS EqualityColumns,
    mid.inequality_columns AS InequalityColumns,
    mid.included_columns AS IncludedColumns
FROM sys.dm_db_missing_index_details mid
INNER JOIN sys.dm_db_missing_index_groups mig
    ON mid.index_handle = mig.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats migs
    ON mig.index_group_handle = migs.group_handle
ORDER BY (migs.avg_user_impact * migs.user_seeks) DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    PARAMETER SNIFFING CANDIDATES (HIGH RUNTIME VARIANCE)
-------------------------------------------------------------------------------
.PURPOSE
    Identify cached queries exhibiting severe variance between min and max duration.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.min_elapsed_time / 1000.0 AS MinElapsedMs,
    qs.max_elapsed_time / 1000.0 AS MaxElapsedMs,
    (qs.total_elapsed_time / NULLIF(qs.execution_count, 0)) / 1000.0 AS AvgElapsedMs,
    CAST(qs.max_elapsed_time AS FLOAT) / NULLIF(qs.min_elapsed_time, 0) AS ElapsedVarianceRatio,
    qs.min_worker_time / 1000.0 AS MinWorkerMs,
    qs.max_worker_time / 1000.0 AS MaxWorkerMs,
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
WHERE qs.execution_count >= 5
  AND qs.min_elapsed_time > 0
ORDER BY ElapsedVarianceRatio DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    QUERY STORE OVERVIEW & DATABASE ANALYSIS
-------------------------------------------------------------------------------
.PURPOSE
    Check Query Store status across all databases. If enabled in current database,
    display top regressed queries.
-----------------------------------------------------------------------------*/

-- Check instance-wide Query Store enablement
SELECT
    d.name AS DatabaseName,
    d.is_query_store_on AS IsQueryStoreOn,
    qso.actual_state_desc AS ActualState,
    qso.readonly_reason_desc AS ReadOnlyReason
FROM sys.databases d
LEFT JOIN sys.database_query_store_options qso
    ON d.database_id = DB_ID()
WHERE d.database_id > 4;

-- If enabled in the current database, query runtime stats
IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state_desc IN ('READ_WRITE', 'READ_ONLY'))
BEGIN
    SELECT TOP (20)
        qsq.query_id,
        qsp.plan_id,
        rs.count_executions AS ExecutionCount,
        rs.avg_duration / 1000.0 AS AvgDurationMs,
        rs.avg_cpu_time / 1000.0 AS AvgCPUMs,
        rs.avg_logical_io_reads AS AvgLogicalReads,
        qsqt.query_sql_text AS QueryText
    FROM sys.query_store_query qsq
    INNER JOIN sys.query_store_plan qsp
        ON qsq.query_id = qsp.query_id
    INNER JOIN sys.query_store_runtime_stats rs
        ON qsp.plan_id = rs.plan_id
    INNER JOIN sys.query_store_query_text qsqt
        ON qsq.query_text_id = qsqt.query_text_id
    ORDER BY rs.avg_duration DESC;
END;
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    EXECUTION PLANS FOR TOP REGRESSED / EXPENSIVE QUERIES
-------------------------------------------------------------------------------
.PURPOSE
    Retrieve graphical execution plans for top 5 CPU consuming statements.
-----------------------------------------------------------------------------*/

SELECT TOP (5)
    qs.total_worker_time / 1000 AS TotalCPUms,
    qs.execution_count,
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
    SECTION 11
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    High-level query performance dashboard.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE session_id > 50 AND session_id <> @@SPID) AS ActiveUserRequests,
    (SELECT COUNT(*) FROM sys.dm_exec_query_stats) AS TotalCachedQueries,
    (SELECT COUNT(*) FROM sys.dm_db_missing_index_details) AS MissingIndexesTotal,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants WHERE grant_time IS NULL) AS WaitingMemoryGrants;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
QUERY PERFORMANCE SYMPTOM           ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
High Logical Reads (Table Scans)    --> Implement covering indexes (Section 7)
High Runtime Variance (Ratio >10x)  --> Investigate parameter sniffing; OPTIMIZE FOR / RECOMPILE
High MaxGrantMB >> MaxUsedGrantMB   --> Cardinality overestimation; update statistics
Regressed Query Store Plan          --> Force known good plan using sp_query_store_force_plan
******************************************************************************/
