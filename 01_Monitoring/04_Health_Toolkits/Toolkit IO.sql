/******************************************************************************
SQL SERVER IO HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

.PURPOSE

This toolkit provides a structured approach for investigating
I/O-related performance issues in SQL Server.

.AREAS COVERED

1. File I/O Overview
2. Data vs Log File Latency
3. I/O Latency per Database
4. Top Read Databases
5. Top Write Databases
6. Top Read Queries
7. Top Write Queries
8. Active I/O Consumers
9. TempDB I/O Analysis
10. PAGEIOLATCH Analysis
11. WRITELOG Analysis
12. Storage File Analysis
13. Wait Statistics Review
14. Executive Summary

.HOW TO USE

Recommended troubleshooting sequence:

    1. Executive Summary
    2. File Latency
    3. Wait Analysis
    4. TempDB Review
    5. Active I/O Consumers
    6. Top Read/Write Queries

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    FILE I/O OVERVIEW
-----------------------------------------------------------------------------

.PURPOSE

   Review overall read/write activity by database file.

.WHY THIS MATTERS

    Identifies files generating the most I/O activity.

.KEY METRICS

    num_of_reads

    num_of_writes

    io_stall_read_ms

    io_stall_write_ms

.HEALTHY

    Low stall times relative to workload.

.WARNING

    Significant stall times.

.POSSIBLE CAUSES

    Storage bottlenecks.
    TempDB pressure.
    Large reporting workloads.

.NEXT ACTIONS

    Review Sections 2, 10 and 11.

-------------------------------------------------------------------------------*/

SELECT
    DB_NAME(vfs.database_id) AS DatabaseName,
    mf.name AS LogicalFileName,
    mf.type_desc,
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(NULL,NULL) vfs
INNER JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id
    AND vfs.file_id = mf.file_id
ORDER BY (vfs.io_stall_read_ms + vfs.io_stall_write_ms) DESC;
GO

/*-------------------------------------------------------------------------------
    SECTION 2
    DATA VS LOG FILE LATENCY
-------------------------------------------------------------------------------

.PURPOSE

    Compare latency between data and log files.

.WHY THIS MATTERS

    Helps identify where storage problems exist.

.HEALTHY

    Read latency < 20 ms

    Write latency < 20 ms

.WARNING

    Read latency > 20 ms

    Write latency > 20 ms

.CRITICAL

    Latency consistently above 100 ms.

.POSSIBLE CAUSES

    Slow storage.
    Shared storage contention.
    SAN issues.

.NEXT ACTIONS

    Review infrastructure.
    Review WRITELOG waits.

-------------------------------------------------------------------------------*/

SELECT
    DB_NAME(vfs.database_id) AS DatabaseName,
    mf.type_desc,
    CAST(io_stall_read_ms AS FLOAT)/NULLIF(num_of_reads,0) AS AvgReadLatencyMs,
    CAST(io_stall_write_ms AS FLOAT)/NULLIF(num_of_writes,0) AS AvgWriteLatencyMs
FROM sys.dm_io_virtual_file_stats(NULL,NULL) vfs
JOIN sys.master_files mf
    ON vfs.database_id = mf.database_id
    AND vfs.file_id = mf.file_id
ORDER BY AvgReadLatencyMs DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    I/O LATENCY BY DATABASE
-------------------------------------------------------------------------------

.PURPOSE

    Identify databases generating highest storage latency.

.WHY THIS MATTERS

    Helps quickly narrow investigation scope.

.HEALTHY

    Similar latency across databases.

.WARNING

    One database dominates latency metrics.

.NEXT ACTIONS

    Review workload within affected database.

-------------------------------------------------------------------------------*/

SELECT
    DB_NAME(database_id) AS DatabaseName,
    SUM(io_stall_read_ms) AS TotalReadStallMs,
    SUM(io_stall_write_ms) AS TotalWriteStallMs
FROM sys.dm_io_virtual_file_stats(NULL,NULL)
GROUP BY database_id
ORDER BY (SUM(io_stall_read_ms)+SUM(io_stall_write_ms)) DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    TOP READ DATABASES
-----------------------------------------------------------------------------

.PURPOSE

   Identify databases responsible for most physical reads.

.WARNING

    Large read volume from a single database.

.POSSIBLE CAUSES

    Reporting.
    Missing indexes.
    Large scans.

.NEXT ACTIONS

    Review Section 6.

-------------------------------------------------------------------------------*/

SELECT
    DB_NAME(database_id) AS DatabaseName,
    SUM(num_of_reads) AS TotalReads
FROM sys.dm_io_virtual_file_stats(NULL,NULL)
GROUP BY database_id
ORDER BY TotalReads DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    TOP WRITE DATABASES
-----------------------------------------------------------------------------

.PURPOSE

    Identify databases responsible for most writes.

.WARNING

    Excessive write activity.

.POSSIBLE CAUSES

    ETL.
    Bulk loads.
    Index maintenance.

.NEXT ACTIONS

    Review transaction log activity.

-------------------------------------------------------------------------------*/

SELECT
    DB_NAME(database_id) AS DatabaseName,
    SUM(num_of_writes) AS TotalWrites
FROM sys.dm_io_virtual_file_stats(NULL,NULL)
GROUP BY database_id
ORDER BY TotalWrites DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 6
    TOP READ QUERIES
-------------------------------------------------------------------------------

.PURPOSE

    Identify queries generating highest logical reads.

.WHY THIS MATTERS

    Large read workloads increase I/O pressure.

.WARNING

    Queries with excessive logical reads.

.POSSIBLE CAUSES

    Missing indexes.
    Scans.
    Poor filtering.

.NEXT ACTIONS

    Review execution plans.

-------------------------------------------------------------------------------*/

SELECT TOP 20
    qs.execution_count,
    qs.total_logical_reads,
    qs.total_logical_reads / qs.execution_count AS AvgReads,
    SUBSTRING(st.text,
              (qs.statement_start_offset/2)+1,
              ((CASE qs.statement_end_offset
                    WHEN -1 THEN DATALENGTH(st.text)
                    ELSE qs.statement_end_offset
                END - qs.statement_start_offset)/2)+1) AS QueryText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_logical_reads DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 7
    TOP WRITE QUERIES
-------------------------------------------------------------------------------

.PURPOSE

    Identify queries generating highest write activity.

.WARNING

    High write workloads.

.POSSIBLE CAUSES

    Batch updates.
    ETL processes.
    Index maintenance.

.NEXT ACTIONS

    Review write-heavy workloads.

-------------------------------------------------------------------------------*/

SELECT TOP 20
    qs.execution_count,
    qs.total_logical_writes,
    qs.total_logical_writes / qs.execution_count AS AvgWrites,
    SUBSTRING(st.text,
              (qs.statement_start_offset/2)+1,
              ((CASE qs.statement_end_offset
                    WHEN -1 THEN DATALENGTH(st.text)
                    ELSE qs.statement_end_offset
                END - qs.statement_start_offset)/2)+1) AS QueryText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_logical_writes DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 8
    ACTIVE I/O CONSUMERS
-------------------------------------------------------------------------------

.PURPOSE

    Show active requests performing significant reads or writes.

.WARNING

    High reads/writes by active sessions.

.NEXT ACTIONS

    Capture execution plans.

-------------------------------------------------------------------------------*/

SELECT
    session_id,
    reads,
    writes,
    logical_reads,
    status,
    command,
    DB_NAME(database_id) AS DatabaseName
FROM sys.dm_exec_requests
WHERE session_id > 50
ORDER BY logical_reads DESC;

GO

/*-----------------------------------------------------------------------------
    SECTION 9
    TEMPDB I/O ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Determine TempDB I/O pressure.

.WHY THIS MATTERS

    TempDB is a frequent source of storage bottlenecks.

.WARNING

    TempDB file latency significantly exceeds user databases.

.POSSIBLE CAUSES

    Sort spills.
    Hash spills.
    Version Store activity.

.NEXT ACTIONS

    Review TempDB Health Toolkit.

-------------------------------------------------------------------------------*/

SELECT
    mf.name,
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(DB_ID('tempdb'), NULL) vfs
JOIN tempdb.sys.database_files mf
    ON vfs.file_id = mf.file_id;

GO

/*-------------------------------------------------------------------------------
    SECTION 10
    PAGEIOLATCH ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Review waits associated with physical reads.

.WHY THIS MATTERS

    Indicates SQL Server waiting on data pages from disk.

.HEALTHY

    Present but not dominant.

.WARNING

    One of the top waits.

.POSSIBLE CAUSES

    Storage latency.
    Insufficient memory.
    Large scans.

.NEXT ACTIONS

    Review Memory Health Toolkit.
    Review file latency.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGEIOLATCH%';

GO

/*-------------------------------------------------------------------------------
    SECTION 11
    WRITELOG ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Review waits associated with transaction log writes.

.WHY THIS MATTERS

    Log latency impacts transaction throughput.

.HEALTHY

    WRITELOG not among top waits.

.WARNING

    Significant WRITELOG waits.

.POSSIBLE CAUSES

    Slow log disk.
    Excessive transaction volume.

.NEXT ACTIONS

    Review log file storage.
    Review write-intensive workloads.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type = 'WRITELOG';

GO

/*-------------------------------------------------------------------------------
    SECTION 12
    STORAGE FILE ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Review physical file layout.

.WHY THIS MATTERS

    Data and log files should be properly distributed.

.WARNING

    Excessive growth events.
    Large files on slow disks.

.NEXT ACTIONS

    Review storage architecture.

-------------------------------------------------------------------------------*/

SELECT
    DB_NAME(database_id) AS DatabaseName,
    name,
    physical_name,
    size/128 AS SizeMB,
    growth,
    type_desc
FROM sys.master_files
ORDER BY database_id;

GO

/*------------------------------------------------------------------------------
    SECTION 13
    I/O WAIT STATISTICS REVIEW
-------------------------------------------------------------------------------

.PURPOSE

    Review waits commonly associated with storage bottlenecks.

.KEY WAITS

    PAGEIOLATCH_SH
    PAGEIOLATCH_EX
    WRITELOG
    IO_COMPLETION

.WARNING

    Dominant I/O waits.

.NEXT ACTIONS

    Correlate waits with file latency metrics.

-------------------------------------------------------------------------------*/

SELECT TOP 25
    wait_type,
    wait_time_ms,
    signal_wait_time_ms,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type IN
(
    'PAGEIOLATCH_SH',
    'PAGEIOLATCH_EX',
    'WRITELOG',
    'IO_COMPLETION'
)
ORDER BY wait_time_ms DESC;

GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

STORAGE BOTTLENECK

INDICATORS

    High Read Latency

    High PAGEIOLATCH waits

REVIEW

    Sections 1, 2, 10 and 13

------------------------------------------------------------------------------
TRANSACTION LOG BOTTLENECK

INDICATORS

    High WRITELOG waits

    High Write Latency

REVIEW

    Sections 2, 5 and 11

------------------------------------------------------------------------------
QUERY DESIGN ISSUE

INDICATORS

    Excessive Logical Reads

    Excessive Physical Reads

REVIEW

    Sections 6 and 8

------------------------------------------------------------------------------
TEMPD B PRESSURE

INDICATORS

    TempDB latency

    TempDB-heavy workloads

REVIEW

    Section 9

------------------------------------------------------------------------------
MEMORY MAY BE ROOT CAUSE

INDICATORS

    PAGEIOLATCH waits

    Low PLE

    Memory Pressure

REVIEW

    Health Memory Toolkit

******************************************************************************
END OF IO HEALTH CHECK
******************************************************************************/