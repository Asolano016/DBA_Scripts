/******************************************************************************
SQL SERVER I/O & STORAGE HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a structured approach for investigating physical storage
performance, data and log file latencies, stall times, TempDB I/O bottlenecks,
and I/O-related wait statistics.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Database File I/O & Stall Time Overview
2. Data vs Transaction Log Latency by File
3. Aggregate I/O Latency by Database
4. Top Read-Intensive Databases
5. Top Write-Intensive Databases
6. Top Logical Read Queries (Historical)
7. Top Logical Write Queries (Historical)
8. Active I/O Consuming Requests
9. TempDB File Latency & Stall Analysis
10. Physical Read Waits (PAGEIOLATCH_*)
11. Transaction Log Flush Waits (WRITELOG)
12. Physical File Layout & Growth Configuration
13. Storage-Related Wait Statistics
14. Executive Summary & Storage Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Executive Summary & File Latency
    2. Data vs Log Latencies (<20ms healthy, >50ms warning, >100ms critical)
    3. PAGEIOLATCH and WRITELOG Wait Analysis
    4. Active & Historical I/O Heavy Queries

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    DATABASE FILE I/O & STALL TIME OVERVIEW
-------------------------------------------------------------------------------
.PURPOSE
    Review overall read/write activity and cumulative stall times across files.

.NOTE
    Metrics from sys.dm_io_virtual_file_stats are cumulative since instance startup.
-----------------------------------------------------------------------------*/

SELECT
    DB_NAME(vfs.database_id) AS DatabaseName,
    mf.name AS LogicalFileName,
    mf.type_desc AS FileType,
    mf.physical_name AS PhysicalPath,
    vfs.num_of_reads AS NumberOfReads,
    vfs.num_of_writes AS NumberOfWrites,
    vfs.io_stall_read_ms AS ReadStallMs,
    vfs.io_stall_write_ms AS WriteStallMs,
    (vfs.io_stall_read_ms + vfs.io_stall_write_ms) AS TotalStallMs
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
INNER JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id
    AND vfs.file_id = mf.file_id
ORDER BY TotalStallMs DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    DATA VS TRANSACTION LOG LATENCY BY FILE
-------------------------------------------------------------------------------
.PURPOSE
    Calculate average read and write latencies per file in milliseconds.

.BENCHMARKS
    < 10-20 ms: Healthy / Standard SSD/SAN
    20 - 50 ms: Warning (Storage throttling or queueing)
    > 50 - 100 ms: Critical storage bottleneck
-----------------------------------------------------------------------------*/

SELECT
    DB_NAME(vfs.database_id) AS DatabaseName,
    mf.name AS LogicalFileName,
    mf.type_desc AS FileType,
    CAST(vfs.io_stall_read_ms AS FLOAT) / NULLIF(vfs.num_of_reads, 0) AS AvgReadLatencyMs,
    CAST(vfs.io_stall_write_ms AS FLOAT) / NULLIF(vfs.num_of_writes, 0) AS AvgWriteLatencyMs,
    vfs.num_of_bytes_read / 1024 / 1024 AS MBRead,
    vfs.num_of_bytes_written / 1024 / 1024 AS MBWritten
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
INNER JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id
    AND vfs.file_id = mf.file_id
ORDER BY AvgReadLatencyMs DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    AGGREGATE I/O LATENCY BY DATABASE
-------------------------------------------------------------------------------
.PURPOSE
    Identify databases generating the highest aggregate storage latency.
-----------------------------------------------------------------------------*/

SELECT
    DB_NAME(database_id) AS DatabaseName,
    SUM(io_stall_read_ms) AS TotalReadStallMs,
    SUM(io_stall_write_ms) AS TotalWriteStallMs,
    SUM(io_stall_read_ms + io_stall_write_ms) AS TotalStallMs,
    SUM(num_of_bytes_read) / 1024 / 1024 AS TotalMBRead,
    SUM(num_of_bytes_written) / 1024 / 1024 AS TotalMBWritten
FROM sys.dm_io_virtual_file_stats(NULL, NULL)
GROUP BY database_id
ORDER BY TotalStallMs DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    TOP READ-INTENSIVE DATABASES
-------------------------------------------------------------------------------
.PURPOSE
    Identify databases responsible for the highest physical read volume.
-----------------------------------------------------------------------------*/

SELECT
    DB_NAME(database_id) AS DatabaseName,
    SUM(num_of_reads) AS TotalPhysicalReads,
    SUM(num_of_bytes_read) / 1024 / 1024 AS TotalMBRead
FROM sys.dm_io_virtual_file_stats(NULL, NULL)
GROUP BY database_id
ORDER BY TotalPhysicalReads DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    TOP WRITE-INTENSIVE DATABASES
-------------------------------------------------------------------------------
.PURPOSE
    Identify databases responsible for the highest physical write activity.
-----------------------------------------------------------------------------*/

SELECT
    DB_NAME(database_id) AS DatabaseName,
    SUM(num_of_writes) AS TotalPhysicalWrites,
    SUM(num_of_bytes_written) / 1024 / 1024 AS TotalMBWritten
FROM sys.dm_io_virtual_file_stats(NULL, NULL)
GROUP BY database_id
ORDER BY TotalPhysicalWrites DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    TOP LOGICAL READ QUERIES (HISTORICAL)
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries generating the highest logical reads driving I/O and cache churn.
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
    SECTION 7
    TOP LOGICAL WRITE QUERIES (HISTORICAL)
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries driving the highest logical write activity.
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
    SECTION 8
    ACTIVE I/O CONSUMING REQUESTS
-------------------------------------------------------------------------------
.PURPOSE
    Show active requests currently performing heavy logical or physical I/O.
-----------------------------------------------------------------------------*/

SELECT
    r.session_id,
    r.status,
    r.reads AS PhysicalReads,
    r.logical_reads AS LogicalReads,
    r.writes AS PhysicalWrites,
    r.total_elapsed_time AS ElapsedTimeMs,
    r.wait_type,
    r.wait_time AS WaitTimeMs,
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
ORDER BY r.logical_reads DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    TEMPDB FILE LATENCY & STALL ANALYSIS
-------------------------------------------------------------------------------
.PURPOSE
    Inspect storage latency specifically across all TempDB data and log files.
-----------------------------------------------------------------------------*/

SELECT
    mf.name AS LogicalFileName,
    mf.type_desc AS FileType,
    mf.physical_name AS PhysicalPath,
    vfs.num_of_reads AS NumberOfReads,
    vfs.num_of_writes AS NumberOfWrites,
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
    PHYSICAL READ WAITS (PAGEIOLATCH)
-------------------------------------------------------------------------------
.PURPOSE
    Review cumulative waits associated with reading data pages from storage.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGEIOLATCH%'
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 11
    TRANSACTION LOG FLUSH WAITS (WRITELOG)
-------------------------------------------------------------------------------
.PURPOSE
    Review log flush latency. High WRITELOG indicates log disk latency.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type = 'WRITELOG';
GO

/*-----------------------------------------------------------------------------
    SECTION 12
    PHYSICAL FILE LAYOUT & GROWTH CONFIGURATION
-------------------------------------------------------------------------------
.PURPOSE
    Review file locations, sizing, and autogrowth settings across all databases.
-----------------------------------------------------------------------------*/

SELECT
    DB_NAME(database_id) AS DatabaseName,
    name AS LogicalFileName,
    type_desc AS FileType,
    size * 8 / 1024 AS SizeMB,
    CASE
        WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + '%'
        ELSE CAST(growth * 8 / 1024 AS VARCHAR(10)) + ' MB'
    END AS AutoGrowthSetting,
    physical_name AS PhysicalFilePath
FROM sys.master_files
ORDER BY database_id, file_id;
GO

/*-----------------------------------------------------------------------------
    SECTION 13
    STORAGE-RELATED WAIT STATISTICS
-------------------------------------------------------------------------------
.PURPOSE
    Review top storage and disk I/O wait categories.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type IN
(
    'PAGEIOLATCH_SH',
    'PAGEIOLATCH_EX',
    'PAGEIOLATCH_UP',
    'WRITELOG',
    'IO_COMPLETION',
    'ASYNC_IO_COMPLETION'
)
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 14
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    High-level storage and I/O summary.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT DATEDIFF(DAY, sqlserver_start_time, GETDATE()) FROM sys.dm_os_sys_info) AS UptimeDays,
    (SELECT SUM(io_stall_read_ms + io_stall_write_ms) FROM sys.dm_io_virtual_file_stats(NULL, NULL)) AS TotalInstanceStallMs,
    (SELECT SUM(wait_time_ms) FROM sys.dm_os_wait_stats WHERE wait_type LIKE 'PAGEIOLATCH%') AS TotalPageIOLatchWaitMs,
    (SELECT SUM(wait_time_ms) FROM sys.dm_os_wait_stats WHERE wait_type = 'WRITELOG') AS TotalWriteLogWaitMs;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
STORAGE SYMPTOM                     ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
High PAGEIOLATCH Read Latency (>20ms)--> Review slow disks, add memory, tune queries
High WRITELOG Wait Time (>10ms avg)  --> Move transaction logs to faster storage / SSD
TempDB High I/O Stalls               --> Review Toolkit TempDB.sql & add data files
High Percent Autogrowth on Large DB  --> Switch autogrowth to fixed MB chunks (e.g. 512MB/1GB)
******************************************************************************/
