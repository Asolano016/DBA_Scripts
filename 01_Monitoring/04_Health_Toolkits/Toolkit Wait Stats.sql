/******************************************************************************
SQL SERVER WAIT STATISTICS HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a structured approach for investigating SQL Server
performance bottlenecks through wait statistics analysis.

SQL Server threads spend their lifecycle either executing (RUNNING), ready to
execute on a scheduler (RUNNABLE / Signal Wait), or waiting for an external
resource such as I/O, locks, memory grants, or network buffers (SUSPENDED / Resource Wait).

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Instance Baseline & Uptime
2. Overall Filtered Top Waits
3. Signal vs Resource Wait Ratio
4. Wait Categorization by Subsystem
5. CPU & Scheduler Related Waits
6. Parallelism Waits (CXPACKET vs CXCONSUMER)
7. Memory & Grant Related Waits
8. Physical Disk I/O Waits (PAGEIOLATCH)
9. Transaction Log Flushes (WRITELOG)
10. Lock & Concurrency Waits (LCK_M_*)
11. In-Memory Latch Contention (PAGELATCH_*)
12. Worker Thread Starvation (THREADPOOL)
13. Network & Client Consumption (ASYNC_NETWORK_IO)
14. Availability Group & HADR Waits
15. Executive Summary & Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Review Uptime & Executive Summary
    2. Review Overall Filtered Top Waits & Signal Wait Ratio
    3. Determine Dominant Category (CPU, Storage, Locking, Memory, HADR)
    4. Open the corresponding Health Toolkit

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    INSTANCE BASELINE & UPTIME
-------------------------------------------------------------------------------
.PURPOSE
    Show SQL Server startup time and elapsed days to baseline cumulative metrics.

.WHY THIS MATTERS
    Wait stats are cumulative since service start (or manual DBCC SQLPERF reset).
    Analyzing wait totals without knowing uptime can lead to false conclusions.
-----------------------------------------------------------------------------*/

SELECT
    GETDATE() AS CaptureTime,
    sqlserver_start_time,
    DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS DaysUptime,
    DATEDIFF(HOUR, sqlserver_start_time, GETDATE()) AS HoursUptime,
    cpu_count,
    hyperthread_ratio
FROM sys.dm_os_sys_info;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    OVERALL TOP WAITS (BENIGN WAITS EXCLUDED)
-------------------------------------------------------------------------------
.PURPOSE
    Identify the top actionable waits accumulated by the instance.

.WHY THIS MATTERS
    Unfiltered wait queries include hundreds of harmless background worker
    waits (e.g. DIRTY_PAGE_POLL, CHECKPOINT_QUEUE) that mislead DBAs.

.HEALTHY
    Waits are evenly distributed with low average wait times per task.

.WARNING
    A single wait type accounts for >40% of total non-benign wait time.
-----------------------------------------------------------------------------*/

WITH FilteredWaits AS
(
    SELECT
        wait_type,
        waiting_tasks_count,
        wait_time_ms,
        max_wait_time_ms,
        signal_wait_time_ms,
        wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms,
        100.0 * wait_time_ms / NULLIF(SUM(wait_time_ms) OVER(), 0) AS WaitPct,
        CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN
    (
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
        N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE', N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT',
        N'CLR_SEMAPHORE', N'CXCONSUMER', N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC', N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSOP_RWLOCK',
        N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT',
        N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE', N'KSOURCE_WAKEUP',
        N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE',
        N'PARALLEL_REDO_DRAIN_WORKER', N'PARALLEL_REDO_LOG_CACHE', N'PARALLEL_REDO_TRAN_LIST',
        N'PARALLEL_REDO_WORKER_SYNC', N'PARALLEL_REDO_WORKER_WAIT_WORK', N'PREEMPTIVE_HADR_LEASE_MECHANISM',
        N'PREEMPTIVE_SP_SERVER_DIAGNOSTICS', N'PREEMPTIVE_OS_LIBRARYOPS', N'PREEMPTIVE_OS_COMOPS',
        N'PREEMPTIVE_OS_CRYPTOPS', N'PREEMPTIVE_OS_PIPEOPS', N'PREEMPTIVE_OS_AUTHENTICATIONOPS',
        N'PREEMPTIVE_OS_GENERICOPS', N'PREEMPTIVE_OS_VERIFYTRUST', N'PREEMPTIVE_OS_FILEOPS',
        N'PREEMPTIVE_OS_DEVICEOPS', N'PREEMPTIVE_OS_QUERYREGISTRY', N'PREEMPTIVE_XE_CALLBACKEXECUTE',
        N'PREEMPTIVE_XE_DISPATCHER', N'PREEMPTIVE_XE_GETTARGETSTATE', N'PREEMPTIVE_XE_SESSIONCOMMIT',
        N'PREEMPTIVE_XE_TARGETINIT', N'PREEMPTIVE_XE_TARGETFINALIZE', N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'PWAIT_EXTENSIBILITY_CLEANUP_TASK', N'QDS_PERSIST_TASK_TRACE_CACHE_MUTEX', N'QDS_ASYNC_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK',
        N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SOS_WORK_DISPATCHER', N'SP_SERVER_DIAGNOSTICS_SLEEP',
        N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES',
        N'STARTUP_DEPENDENCY_MANAGER', N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
        N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE',
        N'XE_BUFFERMGR_ALLPROCESSED_EVENT', N'XE_DISPATCHER_JOIN', N'XE_DISPATCHER_WAIT',
        N'XE_LIVE_TARGET_TVF', N'XE_TIMER_EVENT'
    )
    AND wait_type NOT LIKE N'SLEEP_%'
    AND wait_type NOT LIKE N'PREEMPTIVE_%'
)
SELECT TOP (25)
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    resource_wait_time_ms,
    CAST(WaitPct AS DECIMAL(5,2)) AS WaitPercentage,
    CAST(AvgWaitTimeMs AS DECIMAL(10,2)) AS AvgWaitTimeMs
FROM FilteredWaits
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    SIGNAL VS RESOURCE WAITS (FILTERED)
-------------------------------------------------------------------------------
.PURPOSE
    Determine whether the instance is primarily CPU scheduler bound or resource bound.

.WHY THIS MATTERS
    Signal wait time measures how long a runnable thread waits for an available CPU scheduler.
    High signal wait % (>15-20%) indicates CPU saturation and runnable queue bottlenecks.
-----------------------------------------------------------------------------*/

WITH FilteredWaits AS
(
    SELECT
        wait_time_ms,
        signal_wait_time_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN
    (
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
        N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE', N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT',
        N'CLR_SEMAPHORE', N'CXCONSUMER', N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC', N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSOP_RWLOCK',
        N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT',
        N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE', N'KSOURCE_WAKEUP',
        N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE',
        N'PARALLEL_REDO_DRAIN_WORKER', N'PARALLEL_REDO_LOG_CACHE', N'PARALLEL_REDO_TRAN_LIST',
        N'PARALLEL_REDO_WORKER_SYNC', N'PARALLEL_REDO_WORKER_WAIT_WORK', N'PREEMPTIVE_HADR_LEASE_MECHANISM',
        N'PREEMPTIVE_SP_SERVER_DIAGNOSTICS', N'PREEMPTIVE_OS_LIBRARYOPS', N'PREEMPTIVE_OS_COMOPS',
        N'PREEMPTIVE_OS_CRYPTOPS', N'PREEMPTIVE_OS_PIPEOPS', N'PREEMPTIVE_OS_AUTHENTICATIONOPS',
        N'PREEMPTIVE_OS_GENERICOPS', N'PREEMPTIVE_OS_VERIFYTRUST', N'PREEMPTIVE_OS_FILEOPS',
        N'PREEMPTIVE_OS_DEVICEOPS', N'PREEMPTIVE_OS_QUERYREGISTRY', N'PREEMPTIVE_XE_CALLBACKEXECUTE',
        N'PREEMPTIVE_XE_DISPATCHER', N'PREEMPTIVE_XE_GETTARGETSTATE', N'PREEMPTIVE_XE_SESSIONCOMMIT',
        N'PREEMPTIVE_XE_TARGETINIT', N'PREEMPTIVE_XE_TARGETFINALIZE', N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'PWAIT_EXTENSIBILITY_CLEANUP_TASK', N'QDS_PERSIST_TASK_TRACE_CACHE_MUTEX', N'QDS_ASYNC_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK',
        N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SOS_WORK_DISPATCHER', N'SP_SERVER_DIAGNOSTICS_SLEEP',
        N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES',
        N'STARTUP_DEPENDENCY_MANAGER', N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
        N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE',
        N'XE_BUFFERMGR_ALLPROCESSED_EVENT', N'XE_DISPATCHER_JOIN', N'XE_DISPATCHER_WAIT',
        N'XE_LIVE_TARGET_TVF', N'XE_TIMER_EVENT'
    )
    AND wait_type NOT LIKE N'SLEEP_%'
    AND wait_type NOT LIKE N'PREEMPTIVE_%'
)
SELECT
    SUM(wait_time_ms) AS TotalFilteredWaitMs,
    SUM(signal_wait_time_ms) AS TotalSignalWaitMs,
    SUM(wait_time_ms - signal_wait_time_ms) AS TotalResourceWaitMs,
    CAST(100.0 * SUM(signal_wait_time_ms) / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(5,2)) AS SignalWaitPercentage,
    CAST(100.0 * SUM(wait_time_ms - signal_wait_time_ms) / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(5,2)) AS ResourceWaitPercentage
FROM FilteredWaits;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    WAIT CATEGORIZATION BY SUBSYSTEM
-------------------------------------------------------------------------------
.PURPOSE
    Group wait statistics into actionable operational categories.
-----------------------------------------------------------------------------*/

WITH CategorizedWaits AS
(
    SELECT
        CASE
            WHEN wait_type IN ('SOS_SCHEDULER_YIELD', 'THREADPOOL') THEN 'CPU & Scheduling'
            WHEN wait_type IN ('CXPACKET', 'CXCONSUMER') THEN 'Parallelism'
            WHEN wait_type LIKE 'PAGEIOLATCH%' OR wait_type = 'IO_COMPLETION' THEN 'Physical Disk I/O'
            WHEN wait_type = 'WRITELOG' THEN 'Transaction Log / Commit'
            WHEN wait_type LIKE 'LCK_M_%' THEN 'Locking & Concurrency'
            WHEN wait_type LIKE 'PAGELATCH%' THEN 'In-Memory Latch Contention'
            WHEN wait_type IN ('RESOURCE_SEMAPHORE', 'CMEMTHREAD') THEN 'Memory Grants & Clerks'
            WHEN wait_type = 'ASYNC_NETWORK_IO' THEN 'Network & Client Consumption'
            WHEN wait_type LIKE 'HADR_%' THEN 'Always On Availability Groups'
            ELSE 'Other'
        END AS WaitCategory,
        wait_time_ms,
        signal_wait_time_ms,
        waiting_tasks_count
    FROM sys.dm_os_wait_stats
    WHERE wait_type NOT IN
    (
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
        N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE', N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT',
        N'CLR_SEMAPHORE', N'CXCONSUMER', N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC', N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSOP_RWLOCK',
        N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT',
        N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE', N'KSOURCE_WAKEUP',
        N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE',
        N'PARALLEL_REDO_DRAIN_WORKER', N'PARALLEL_REDO_LOG_CACHE', N'PARALLEL_REDO_TRAN_LIST',
        N'PARALLEL_REDO_WORKER_SYNC', N'PARALLEL_REDO_WORKER_WAIT_WORK', N'PREEMPTIVE_HADR_LEASE_MECHANISM',
        N'PREEMPTIVE_SP_SERVER_DIAGNOSTICS', N'PREEMPTIVE_OS_LIBRARYOPS', N'PREEMPTIVE_OS_COMOPS',
        N'PREEMPTIVE_OS_CRYPTOPS', N'PREEMPTIVE_OS_PIPEOPS', N'PREEMPTIVE_OS_AUTHENTICATIONOPS',
        N'PREEMPTIVE_OS_GENERICOPS', N'PREEMPTIVE_OS_VERIFYTRUST', N'PREEMPTIVE_OS_FILEOPS',
        N'PREEMPTIVE_OS_DEVICEOPS', N'PREEMPTIVE_OS_QUERYREGISTRY', N'PREEMPTIVE_XE_CALLBACKEXECUTE',
        N'PREEMPTIVE_XE_DISPATCHER', N'PREEMPTIVE_XE_GETTARGETSTATE', N'PREEMPTIVE_XE_SESSIONCOMMIT',
        N'PREEMPTIVE_XE_TARGETINIT', N'PREEMPTIVE_XE_TARGETFINALIZE', N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'PWAIT_EXTENSIBILITY_CLEANUP_TASK', N'QDS_PERSIST_TASK_TRACE_CACHE_MUTEX', N'QDS_ASYNC_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK',
        N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SOS_WORK_DISPATCHER', N'SP_SERVER_DIAGNOSTICS_SLEEP',
        N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES',
        N'STARTUP_DEPENDENCY_MANAGER', N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
        N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE',
        N'XE_BUFFERMGR_ALLPROCESSED_EVENT', N'XE_DISPATCHER_JOIN', N'XE_DISPATCHER_WAIT',
        N'XE_LIVE_TARGET_TVF', N'XE_TIMER_EVENT'
    )
    AND wait_type NOT LIKE N'SLEEP_%'
    AND wait_type NOT LIKE N'PREEMPTIVE_%'
)
SELECT
    WaitCategory,
    SUM(waiting_tasks_count) AS TotalWaitingTasks,
    SUM(wait_time_ms) AS TotalWaitTimeMs,
    SUM(signal_wait_time_ms) AS TotalSignalWaitMs,
    CAST(100.0 * SUM(wait_time_ms) / NULLIF((SELECT SUM(wait_time_ms) FROM CategorizedWaits), 0) AS DECIMAL(5,2)) AS CategoryWaitPercentage
FROM CategorizedWaits
GROUP BY WaitCategory
ORDER BY TotalWaitTimeMs DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    CPU & SCHEDULER RELATED WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Review SOS_SCHEDULER_YIELD and THREADPOOL waits.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('SOS_SCHEDULER_YIELD', 'THREADPOOL');
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    PARALLELISM WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Analyze CXPACKET (coordinator/skew) vs CXCONSUMER (normal parallel consumer).
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('CXPACKET', 'CXCONSUMER');
GO

/*-----------------------------------------------------------------------------
    SECTION 7
    MEMORY GRANT & RESOURCE SEMAPHORE WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries waiting for query memory grant allocation.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('RESOURCE_SEMAPHORE', 'CMEMTHREAD', 'RESOURCE_SEMAPHORE_QUERY_COMPILE');
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    PHYSICAL DISK I/O WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Analyze PAGEIOLATCH wait times representing physical disk read latency.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGEIOLATCH%' OR wait_type = 'IO_COMPLETION'
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    TRANSACTION LOG WRITELOG WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Review synchronous transaction log flush latency.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type = 'WRITELOG';
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    LOCK & CONCURRENCY WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Identify lock wait types indicating blocking contention.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'LCK_M_%'
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 11
    IN-MEMORY LATCH WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Analyze non-I/O memory latch waits (frequent in TempDB allocation contention).
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGELATCH%'
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 12
    WORKER THREAD STARVATION WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Review THREADPOOL waits where SQL Server has exhausted available worker threads.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type = 'THREADPOOL';
GO

/*-----------------------------------------------------------------------------
    SECTION 13
    NETWORK & CLIENT CONSUMPTION WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Review ASYNC_NETWORK_IO waits indicating slow client application fetching.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type = 'ASYNC_NETWORK_IO';
GO

/*-----------------------------------------------------------------------------
    SECTION 14
    ALWAYS ON AVAILABILITY GROUP WAITS
-------------------------------------------------------------------------------
.PURPOSE
    Review HADR waits associated with Availability Group log replication.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'HADR_%'
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 15
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    Provide high-level wait health summary.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT DATEDIFF(DAY, sqlserver_start_time, GETDATE()) FROM sys.dm_os_sys_info) AS UptimeDays,
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE session_id > 50 AND session_id <> @@SPID) AS ActiveRequests,
    (SELECT SUM(wait_time_ms) FROM sys.dm_os_wait_stats WHERE wait_type NOT LIKE 'SLEEP%' AND wait_type NOT LIKE 'PREEMPTIVE%') AS TotalFilteredWaitMs,
    (SELECT SUM(signal_wait_time_ms) FROM sys.dm_os_wait_stats WHERE wait_type NOT LIKE 'SLEEP%' AND wait_type NOT LIKE 'PREEMPTIVE%') AS TotalSignalWaitMs;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
DOMINANT WAIT TYPE                  RECOMMENDED INVESTIGATION TOOLKIT
-------------------------------------------------------------------------------
SOS_SCHEDULER_YIELD / THREADPOOL    --> Toolkit CPU.sql
CXPACKET (High Avg Wait)            --> Toolkit CPU.sql (Parallelism Section)
RESOURCE_SEMAPHORE                  --> Toolkit Memory.sql
PAGEIOLATCH_SH / PAGEIOLATCH_EX     --> Toolkit IO.sql & Toolkit Memory.sql
WRITELOG                            --> Toolkit IO.sql
LCK_M_* (Any lock wait)             --> Toolkit Blocking.sql
PAGELATCH_UP / PAGELATCH_EX         --> Toolkit TempDB.sql
ASYNC_NETWORK_IO                    --> Application consumption / Network RTT
HADR_SYNC_COMMIT                    --> Toolkit Always On.sql
******************************************************************************/
