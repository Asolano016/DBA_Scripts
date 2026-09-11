/******************************************************************************
SQL SERVER TEMPDB HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

PURPOSE

This toolkit helps identify:

1. TempDB configuration issues
2. TempDB file layout problems
3. Sessions consuming TempDB
4. Internal object usage
5. User object usage
6. Version Store pressure
7. TempDB growth pressure
8. Memory spills
9. TempDB I/O bottlenecks
10. Overall TempDB health

RECOMMENDED TROUBLESHOOTING FLOW

    1. Executive Summary
    2. TempDB Configuration
    3. TempDB File Sizes
    4. TempDB Space Usage
    5. Session Consumers
    6. Version Store
    7. Active TempDB Requests
    8. Memory Spills
    9. TempDB I/O Analysis
    10. TempDB Wait Indicators

******************************************************************************/

--------------------------------------------------------------------------------
-- SECTION 1
-- EXECUTIVE SUMMARY
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Quick TempDB health assessment.
--
-- INVESTIGATE
--
--     High Version Store
--     Large Internal Objects
--     Heavy Session Consumers
--
--------------------------------------------------------------------------------

SELECT

    GETDATE() AS CaptureTime,

    SUM(user_object_reserved_page_count) * 8 / 1024 AS UserObjectsMB,

    SUM(internal_object_reserved_page_count) * 8 / 1024 AS InternalObjectsMB,

    SUM(version_store_reserved_page_count) * 8 / 1024 AS VersionStoreMB,

    SUM(unallocated_extent_page_count) * 8 / 1024 AS FreeSpaceMB

FROM tempdb.sys.dm_db_file_space_usage;

GO

--------------------------------------------------------------------------------
-- SECTION 2
-- TEMPDB CONFIGURATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Validate TempDB file count and configuration.
--
-- REVIEW
--
--     Number of data files.
--     Equal sizing.
--     Growth settings.
--
--------------------------------------------------------------------------------

SELECT

    name,
    file_id,
    type_desc,
    size / 128.0 AS SizeMB,
    growth,
    is_percent_growth,
    physical_name

FROM tempdb.sys.database_files
ORDER BY file_id;

GO

--------------------------------------------------------------------------------
-- SECTION 3
-- TEMPDB FILE UTILIZATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review actual file usage.
--
--------------------------------------------------------------------------------

SELECT

    df.name,

    df.type_desc,

    df.size / 128.0 AS AllocatedMB,

    FILEPROPERTY(df.name,'SpaceUsed') / 128.0 AS UsedMB,

    (df.size - FILEPROPERTY(df.name,'SpaceUsed')) / 128.0 AS FreeMB

FROM tempdb.sys.database_files df;

GO

--------------------------------------------------------------------------------
-- SECTION 4
-- TEMPDB SPACE BREAKDOWN
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Understand TempDB space allocation.
--
--------------------------------------------------------------------------------

SELECT

    SUM(user_object_reserved_page_count) * 8 / 1024 AS UserObjectsMB,

    SUM(internal_object_reserved_page_count) * 8 / 1024 AS InternalObjectsMB,

    SUM(version_store_reserved_page_count) * 8 / 1024 AS VersionStoreMB,

    SUM(mixed_extent_page_count) * 8 / 1024 AS MixedExtentMB,

    SUM(unallocated_extent_page_count) * 8 / 1024 AS FreeSpaceMB

FROM tempdb.sys.dm_db_file_space_usage;

GO

--------------------------------------------------------------------------------
-- SECTION 5
-- TOP SESSION TEMPDB CONSUMERS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify sessions using TempDB.
--
--------------------------------------------------------------------------------

SELECT TOP 25

    s.session_id,

    s.login_name,

    s.host_name,

    (su.user_objects_alloc_page_count * 8) / 1024 AS UserObjectsMB,

    (su.internal_objects_alloc_page_count * 8) / 1024 AS InternalObjectsMB

FROM sys.dm_db_session_space_usage su

INNER JOIN sys.dm_exec_sessions s
    ON su.session_id = s.session_id

ORDER BY
(
    su.user_objects_alloc_page_count +
    su.internal_objects_alloc_page_count
) DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 6
-- ACTIVE REQUEST TEMPDB CONSUMERS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify requests currently consuming TempDB.
--
--------------------------------------------------------------------------------

SELECT

    r.session_id,

    r.status,

    r.command,

    r.cpu_time,

    r.total_elapsed_time,

    DB_NAME(r.database_id) AS DatabaseName,

    t.text

FROM sys.dm_exec_requests r

CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t

WHERE r.session_id > 50

ORDER BY r.total_elapsed_time DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 7
-- VERSION STORE USAGE
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Monitor snapshot isolation/version store growth.
--
--
-- INVESTIGATE
--
--     Large VersionStoreMB
--     Long running snapshot transactions
--
--------------------------------------------------------------------------------

SELECT

    SUM(version_store_reserved_page_count) * 8 / 1024 AS VersionStoreMB

FROM tempdb.sys.dm_db_file_space_usage;

GO

--------------------------------------------------------------------------------
-- SECTION 8
-- LONG RUNNING SNAPSHOT TRANSACTIONS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify transactions preventing version cleanup.
--
--------------------------------------------------------------------------------

SELECT

    transaction_id,

    elapsed_time_seconds,

    session_id,

    is_snapshot,

    first_snapshot_sequence_num

FROM sys.dm_tran_active_snapshot_database_transactions

ORDER BY elapsed_time_seconds DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 9
-- MEMORY SPILL DETECTION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify queries spilling to TempDB.
--
--
-- WHY THIS MATTERS
--
--     Sort spills
--     Hash spills
--     Insufficient memory grants
--
--------------------------------------------------------------------------------

SELECT TOP 25

    qs.last_execution_time,

    qs.execution_count,

    qs.total_worker_time / 1000 AS TotalCPUms,

    qs.total_elapsed_time / 1000 AS TotalDurationms,

    st.text

FROM sys.dm_exec_query_stats qs

CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st

ORDER BY qs.total_elapsed_time DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 10
-- TEMPDB I/O LATENCY
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review TempDB storage latency.
--
--------------------------------------------------------------------------------

SELECT

    mf.name,

    mf.physical_name,

    vfs.num_of_reads,

    vfs.num_of_writes,

    CASE
        WHEN vfs.num_of_reads = 0
        THEN 0
        ELSE vfs.io_stall_read_ms / vfs.num_of_reads
    END AS AvgReadLatencyMS,

    CASE
        WHEN vfs.num_of_writes = 0
        THEN 0
        ELSE vfs.io_stall_write_ms / vfs.num_of_writes
    END AS AvgWriteLatencyMS

FROM sys.master_files mf

INNER JOIN sys.dm_io_virtual_file_stats(DB_ID('tempdb'), NULL) vfs
    ON mf.database_id = DB_ID('tempdb')
    AND mf.file_id = vfs.file_id

ORDER BY AvgWriteLatencyMS DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 11
-- TEMPDB WAIT STATISTICS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify TempDB related waits.
--
--------------------------------------------------------------------------------

SELECT

    wait_type,

    wait_time_ms,

    waiting_tasks_count,

    signal_wait_time_ms

FROM sys.dm_os_wait_stats

WHERE wait_type IN
(
    'PAGELATCH_EX',
    'PAGELATCH_SH',
    'PAGELATCH_UP',
    'WRITELOG'
)

ORDER BY wait_time_ms DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 12
-- TEMPDB FILE BALANCE
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Verify usage distribution across TempDB files.
--
--------------------------------------------------------------------------------

SELECT

    file_id,

    total_page_count * 8 / 1024 AS TotalMB,

    allocated_extent_page_count * 8 / 1024 AS AllocatedMB,

    unallocated_extent_page_count * 8 / 1024 AS FreeMB

FROM tempdb.sys.dm_db_file_space_usage;

GO

--------------------------------------------------------------------------------
-- SECTION 13
-- MEMORY GRANTS RELATED TO TEMPDB
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify large grants which may spill.
--
--------------------------------------------------------------------------------

SELECT

    session_id,

    requested_memory_kb / 1024 AS RequestedMB,

    granted_memory_kb / 1024 AS GrantedMB,

    used_memory_kb / 1024 AS UsedMB,

    max_used_memory_kb / 1024 AS MaxUsedMB

FROM sys.dm_exec_query_memory_grants

ORDER BY granted_memory_kb DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 14
-- TRIAGE INDICATORS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Quick guidance.
--
--------------------------------------------------------------------------------

SELECT

    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM sys.dm_tran_active_snapshot_database_transactions
        )
        THEN 'YES'
        ELSE 'NO'
    END AS SnapshotTransactionsPresent,

    (
        SELECT
            SUM(version_store_reserved_page_count) * 8 / 1024
        FROM tempdb.sys.dm_db_file_space_usage
    ) AS VersionStoreMB,

    (
        SELECT COUNT(*)
        FROM sys.dm_exec_query_memory_grants
        WHERE grant_time IS NULL
    ) AS WaitingMemoryGrants;

GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

TEMPDB SPACE ISSUE

INDICATORS

    TempDB nearly full
    Large internal objects
    Large user objects

REVIEW

    Sections 1, 3, 4, 5

------------------------------------------------------------------------------
VERSION STORE ISSUE

INDICATORS

    Large Version Store
    Snapshot transactions

REVIEW

    Sections 7, 8, 14

------------------------------------------------------------------------------
TEMPDB I/O ISSUE

INDICATORS

    High write latency
    WRITELOG waits
    PAGELATCH waits

REVIEW

    Sections 10, 11

------------------------------------------------------------------------------
SPILLING ISSUE

INDICATORS

    Large sorts
    Hash operations
    Memory grant pressure

REVIEW

    Sections 9, 13

------------------------------------------------------------------------------
SESSION CONSUMPTION ISSUE

INDICATORS

    One session dominates TempDB

REVIEW

    Sections 5, 6

******************************************************************************
END OF FILE
******************************************************************************/