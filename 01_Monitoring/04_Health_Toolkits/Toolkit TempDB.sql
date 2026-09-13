/******************************************************************************
SQL SERVER TEMPDB HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a structured approach for investigating TempDB space
exhaustion, allocation contention (PAGELATCH_UP/EX), Version Store bloat,
query memory spills to TempDB, and file configuration balance.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. TempDB Space Allocation Overview (User, Internal, Version Store)
2. TempDB File Configuration & Growth Sizing
3. TempDB File Space Breakdown & Utilization
4. Session-Level Space Consumption (Historical / Cumulative)
5. Active Task Space Consumption (In-Flight Queries)
6. Row Version Store Size & Transaction Usage
7. Long-Running Snapshot Isolation Transactions
8. Memory Spill Detection (Sort & Hash Spills to TempDB)
9. TempDB File I/O Latency & Stall Breakdown
10. TempDB-Related Allocation Latch Waits (PAGELATCH_*)
11. Large Memory Grants Vulnerable to Spills
12. Executive Summary & TempDB Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Review Executive Summary & Space Breakdown
    2. Check Session & Active Task Consumers
    3. Check Version Store & Snapshot Transactions
    4. Check Memory Spills & Allocation Latches

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    TEMPDB SPACE ALLOCATION OVERVIEW
-------------------------------------------------------------------------------
.PURPOSE
    Provide high-level breakdown of TempDB space allocation across categories.
-----------------------------------------------------------------------------*/

SELECT
    GETDATE() AS CaptureTime,
    SUM(total_page_count) * 8 / 1024 AS TotalTempDBSizeMB,
    SUM(user_object_reserved_page_count) * 8 / 1024 AS UserObjectsMB,
    SUM(internal_object_reserved_page_count) * 8 / 1024 AS InternalObjectsMB,
    SUM(version_store_reserved_page_count) * 8 / 1024 AS VersionStoreMB,
    SUM(unallocated_extent_page_count) * 8 / 1024 AS FreeSpaceMB,
    CAST(SUM(unallocated_extent_page_count) * 100.0 / NULLIF(SUM(total_page_count), 0) AS DECIMAL(5,2)) AS FreeSpacePercentage
FROM tempdb.sys.dm_db_file_space_usage;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    TEMPDB FILE CONFIGURATION & GROWTH SIZING
-------------------------------------------------------------------------------
.PURPOSE
    Validate equal file sizing, autogrowth settings, and file distribution.

.BEST PRACTICES (SQL 2019+)
    - 1 data file per logical core up to 8 (or 16 on high core counts).
    - All data files must have identical initial size and identical autogrowth in MB (not %).
-----------------------------------------------------------------------------*/

SELECT
    mf.file_id,
    mf.name AS LogicalFileName,
    mf.type_desc AS FileType,
    mf.size * 8 / 1024 AS CurrentSizeMB,
    CASE
        WHEN mf.is_percent_growth = 1 THEN CAST(mf.growth AS VARCHAR(10)) + '%'
        ELSE CAST(mf.growth * 8 / 1024 AS VARCHAR(10)) + ' MB'
    END AS AutoGrowthSetting,
    mf.physical_name AS PhysicalPath
FROM sys.master_files mf
WHERE mf.database_id = DB_ID('tempdb')
ORDER BY mf.file_id;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    TEMPDB FILE SPACE BREAKDOWN & UTILIZATION
-------------------------------------------------------------------------------
.PURPOSE
    Inspect allocation distribution across each individual TempDB data file.
-----------------------------------------------------------------------------*/

SELECT
    fsu.file_id,
    mf.name AS LogicalFileName,
    fsu.total_page_count * 8 / 1024 AS TotalMB,
    fsu.allocated_extent_page_count * 8 / 1024 AS AllocatedMB,
    fsu.unallocated_extent_page_count * 8 / 1024 AS FreeMB,
    fsu.user_object_reserved_page_count * 8 / 1024 AS UserObjectsMB,
    fsu.internal_object_reserved_page_count * 8 / 1024 AS InternalObjectsMB,
    fsu.version_store_reserved_page_count * 8 / 1024 AS VersionStoreMB
FROM tempdb.sys.dm_db_file_space_usage fsu
INNER JOIN sys.master_files mf
    ON fsu.database_id = mf.database_id
    AND fsu.file_id = mf.file_id
WHERE fsu.database_id = DB_ID('tempdb');
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    SESSION-LEVEL SPACE CONSUMPTION (CUMULATIVE)
-------------------------------------------------------------------------------
.PURPOSE
    Identify sessions consuming TempDB for temp tables (#tables) or internal worktables.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    s.status AS SessionStatus,
    (su.user_objects_alloc_page_count - su.user_objects_dealloc_page_count) * 8 / 1024 AS NetUserObjectsMB,
    (su.internal_objects_alloc_page_count - su.internal_objects_dealloc_page_count) * 8 / 1024 AS NetInternalObjectsMB,
    (su.user_objects_alloc_page_count * 8) / 1024 AS TotalUserAllocMB,
    (su.internal_objects_alloc_page_count * 8) / 1024 AS TotalInternalAllocMB
FROM sys.dm_db_session_space_usage su
INNER JOIN sys.dm_exec_sessions s
    ON su.session_id = s.session_id
WHERE s.is_user_process = 1
  AND (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) > 0
ORDER BY (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    ACTIVE TASK SPACE CONSUMPTION (IN-FLIGHT REQUESTS)
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries actively executing right now that are allocating TempDB space.
-----------------------------------------------------------------------------*/

SELECT
    tsu.session_id,
    tsu.request_id,
    r.status AS RequestStatus,
    r.command AS CommandType,
    r.cpu_time AS CPUTimeMs,
    r.total_elapsed_time AS ElapsedTimeMs,
    (tsu.user_objects_alloc_page_count * 8) / 1024 AS TaskUserAllocMB,
    (tsu.internal_objects_alloc_page_count * 8) / 1024 AS TaskInternalAllocMB,
    DB_NAME(r.database_id) AS DatabaseName,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS StatementText
FROM sys.dm_db_task_space_usage tsu
INNER JOIN sys.dm_exec_requests r
    ON tsu.session_id = r.session_id
    AND tsu.request_id = r.request_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE (tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count) > 0
ORDER BY (tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count) DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    ROW VERSION STORE SIZE & USAGE
-------------------------------------------------------------------------------
.PURPOSE
    Monitor Version Store size generated by RCSI, Snapshot Isolation, or Online Indexes.
-----------------------------------------------------------------------------*/

SELECT
    SUM(version_store_reserved_page_count) * 8 / 1024 AS TotalVersionStoreMB
FROM tempdb.sys.dm_db_file_space_usage;
GO

/*-----------------------------------------------------------------------------
    SECTION 7
    LONG-RUNNING SNAPSHOT ISOLATION TRANSACTIONS
-------------------------------------------------------------------------------
.PURPOSE
    Identify transactions holding the oldest snapshot timestamp and blocking version cleanup.
-----------------------------------------------------------------------------*/

SELECT
    ast.transaction_id,
    ast.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    ast.elapsed_time_seconds,
    ast.is_snapshot,
    ast.first_snapshot_sequence_num,
    ast.max_version_chain_traversed,
    ib.event_info AS [LastKnownStatement]
FROM sys.dm_tran_active_snapshot_database_transactions ast
INNER JOIN sys.dm_exec_sessions s
    ON ast.session_id = s.session_id
OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) ib
ORDER BY ast.elapsed_time_seconds DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    MEMORY SPILL DETECTION (SORT & HASH SPILLS TO TEMPDB)
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries whose execution memory grants were insufficient, spilling to TempDB.

.SQL 2019+ SPECIFIC
    Uses total_spills and last_spills columns from sys.dm_exec_query_stats.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_spills AS TotalSpills,
    (qs.total_spills / NULLIF(qs.execution_count, 0)) AS AvgSpillsPerExec,
    qs.last_spills AS LastExecutionSpills,
    qs.total_worker_time / 1000 AS TotalCPUms,
    qs.total_elapsed_time / 1000 AS TotalDurationMs,
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
WHERE qs.total_spills > 0
ORDER BY qs.total_spills DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    TEMPDB FILE I/O LATENCY & STALL BREAKDOWN
-------------------------------------------------------------------------------
.PURPOSE
    Evaluate storage responsiveness specifically on TempDB files.
-----------------------------------------------------------------------------*/

SELECT
    mf.name AS LogicalFileName,
    mf.physical_name AS PhysicalPath,
    vfs.num_of_reads AS Reads,
    vfs.num_of_writes AS Writes,
    CAST(vfs.io_stall_read_ms AS FLOAT) / NULLIF(vfs.num_of_reads, 0) AS AvgReadLatencyMs,
    CAST(vfs.io_stall_write_ms AS FLOAT) / NULLIF(vfs.num_of_writes, 0) AS AvgWriteLatencyMs,
    (vfs.io_stall_read_ms + vfs.io_stall_write_ms) AS TotalStallMs
FROM sys.dm_io_virtual_file_stats(DB_ID('tempdb'), NULL) vfs
INNER JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id
    AND vfs.file_id = mf.file_id
ORDER BY mf.file_id;
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    TEMPDB-RELATED ALLOCATION LATCH WAITS (PAGELATCH_*)
-------------------------------------------------------------------------------
.PURPOSE
    Review PAGELATCH waits indicating PFS/GAM/SGAM allocation page contention.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('PAGELATCH_UP', 'PAGELATCH_EX', 'PAGELATCH_SH')
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 11
    LARGE MEMORY GRANTS VULNERABLE TO SPILLS
-------------------------------------------------------------------------------
.PURPOSE
    Identify active queries with large memory grants that risk spilling on bad estimates.
-----------------------------------------------------------------------------*/

SELECT
    mg.session_id,
    mg.requested_memory_kb / 1024 AS RequestedMB,
    mg.granted_memory_kb / 1024 AS GrantedMB,
    mg.used_memory_kb / 1024 AS UsedMB,
    mg.max_used_memory_kb / 1024 AS MaxUsedMB,
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
    SECTION 12
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    High-level TempDB health dashboard.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT SUM(total_page_count) * 8 / 1024 FROM tempdb.sys.dm_db_file_space_usage) AS TotalTempDBSizeMB,
    (SELECT SUM(unallocated_extent_page_count) * 8 / 1024 FROM tempdb.sys.dm_db_file_space_usage) AS FreeSpaceMB,
    (SELECT SUM(version_store_reserved_page_count) * 8 / 1024 FROM tempdb.sys.dm_db_file_space_usage) AS VersionStoreMB,
    (SELECT COUNT(*) FROM sys.dm_tran_active_snapshot_database_transactions) AS ActiveSnapshotTransactions,
    (SELECT COUNT(*) FROM sys.dm_os_schedulers WHERE scheduler_id < 255) AS VisibleSchedulersCount,
    (SELECT COUNT(*) FROM sys.master_files WHERE database_id = DB_ID('tempdb') AND type_desc = 'ROWS') AS TempDBDataFilesCount;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
TEMPDB SYMPTOM                      ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
Internal Objects Space High         --> Investigate hash joins, sorts, CTEs (Section 5 & 8)
User Objects Space High             --> Identify #temp table creator sessions (Section 4)
Version Store Growing Unchecked     --> Kill or commit oldest snapshot transaction (Section 7)
High PAGELATCH_UP/EX on File 2      --> Verify TempDB has 4-8 equally sized files
High Memory Spills (total_spills)   --> Update table statistics / tune query cardinality
******************************************************************************/
