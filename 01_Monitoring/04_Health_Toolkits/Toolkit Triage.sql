/******************************************************************************
SQL SERVER FIRST RESPONSE TRIAGE & INCIDENT HEALTH CHECK GUIDE
-------------------------------------------------------------------------------
PURPOSE

This is the primary Tier 1 emergency triage script for SQL Server production
incidents. It rapidly inspects all major database engine subsystems to identify
the active bottleneck and direct the DBA to the appropriate deep-dive toolkit.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Instance Baseline & Uptime
2. Active Executing Requests
3. Blocking Chains & Waiters
4. Top Wait Statistics (Benign Filtered)
5. Top CPU Consuming Queries (Historical)
6. Top Logical Read Queries (Historical)
7. Top Duration Queries (Historical)
8. TempDB Space & Session Consumption
9. Plan Cache & Ad-Hoc Bloat
10. High-Impact Missing Index Recommendations
11. Parallelism Configuration
12. Top Active Request Plans (Safe Sample)
13. Executive Summary
14. DBA Triage Decision Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Instance Baseline & Executive Summary
    2. Active Requests & Blocking
    3. Filtered Wait Statistics
    4. Subsystem Deep-Dive (CPU, IO, Memory, TempDB, Concurrency)

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    INSTANCE BASELINE & UPTIME
-------------------------------------------------------------------------------
.PURPOSE
    Establish how long SQL Server has been running to baseline cumulative metrics.

.WHY THIS MATTERS
    Cumulative DMVs (Wait Stats, Query Stats, Missing Indexes) reset on restart.
    A metric accumulated over 30 days has vastly different meaning than one over 30 minutes.

.KEY METRICS
    sqlserver_start_time
    DaysUptime
    cpu_count
    hyperthread_ratio
-----------------------------------------------------------------------------*/

SELECT
    GETDATE() AS CaptureTime,
    sqlserver_start_time,
    DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS DaysUptime,
    DATEDIFF(HOUR, sqlserver_start_time, GETDATE()) AS HoursUptime,
    cpu_count,
    hyperthread_ratio,
    (physical_memory_kb / 1024) AS PhysicalMemoryMB
FROM sys.dm_os_sys_info;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    ACTIVE EXECUTING REQUESTS
-------------------------------------------------------------------------------
.PURPOSE
    Show active user requests currently executing in the engine.

.WHY THIS MATTERS
    During active incidents, identifying long-running or suspended requests
    provides immediate visibility into the active workload.

.KEY METRICS
    session_id
    status
    cpu_time (ms)
    total_elapsed_time (ms)
    wait_type & wait_time (ms)
    blocking_session_id
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
    ) AS StatementText,
    st.text AS FullBatchText
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.session_id <> @@SPID
  AND r.session_id > 50
ORDER BY r.total_elapsed_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    BLOCKING CHAINS & WAITERS
-------------------------------------------------------------------------------
.PURPOSE
    Identify active blocking relationships and lock contention.

.WHY THIS MATTERS
    Blocked sessions degrade application concurrency and lead to connection timeouts.

.HEALTHY
    No rows returned.

.WARNING
    Multiple sessions blocked by a common blocking_session_id.
-----------------------------------------------------------------------------*/

SELECT
    r.session_id AS BlockedSessionId,
    r.blocking_session_id AS BlockerSessionId,
    r.wait_type,
    r.wait_time AS WaitTimeMs,
    r.status,
    r.command,
    DB_NAME(r.database_id) AS DatabaseName,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS BlockedStatementText
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    TOP WAIT STATISTICS (BENIGN WAITS EXCLUDED)
-------------------------------------------------------------------------------
.PURPOSE
    Identify where the SQL Server instance has spent the majority of its wait time.

.WHY THIS MATTERS
    Wait statistics reveal primary server bottlenecks. Harmless background
    system waits must be filtered out to prevent distorted diagnoses.

.KEY METRICS
    WaitPercentage
    signal_wait_time_ms (CPU scheduler delay)
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
        100.0 * wait_time_ms / NULLIF(SUM(wait_time_ms) OVER(), 0) AS WaitPercentage
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
SELECT TOP (20)
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    resource_wait_time_ms,
    CAST(WaitPercentage AS DECIMAL(5,2)) AS WaitPercentage
FROM FilteredWaits
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    TOP CPU CONSUMING QUERIES (HISTORICAL)
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries historically consuming the most aggregate CPU worker time.
-----------------------------------------------------------------------------*/

SELECT TOP (15)
    qs.execution_count,
    qs.total_worker_time / 1000 AS TotalCPUms,
    (qs.total_worker_time / NULLIF(qs.execution_count, 0)) / 1000 AS AvgCPUms,
    qs.total_logical_reads,
    (qs.total_logical_reads / NULLIF(qs.execution_count, 0)) AS AvgLogicalReads,
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
    SECTION 6
    TOP LOGICAL READ QUERIES (HISTORICAL)
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries driving the highest storage read volume and memory churn.
-----------------------------------------------------------------------------*/

SELECT TOP (15)
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
    TOP DURATION QUERIES (HISTORICAL)
-------------------------------------------------------------------------------
.PURPOSE
    Identify queries with the highest average elapsed duration.
-----------------------------------------------------------------------------*/

SELECT TOP (15)
    qs.execution_count,
    qs.total_elapsed_time / 1000 AS TotalDurationMs,
    (qs.total_elapsed_time / NULLIF(qs.execution_count, 0)) / 1000 AS AvgDurationMs,
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
    SECTION 8
    TEMPDB ALLOCATION & TOP SESSION CONSUMERS
-------------------------------------------------------------------------------
.PURPOSE
    Assess TempDB space pressure and identify top consumer sessions.
-----------------------------------------------------------------------------*/

SELECT
    SUM(user_object_reserved_page_count) * 8 / 1024 AS TempDB_UserObjectsMB,
    SUM(internal_object_reserved_page_count) * 8 / 1024 AS TempDB_InternalObjectsMB,
    SUM(version_store_reserved_page_count) * 8 / 1024 AS TempDB_VersionStoreMB,
    SUM(unallocated_extent_page_count) * 8 / 1024 AS TempDB_FreeSpaceMB
FROM tempdb.sys.dm_db_file_space_usage;

SELECT TOP (10)
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    (su.user_objects_alloc_page_count * 8) / 1024 AS UserObjectsAllocMB,
    (su.internal_objects_alloc_page_count * 8) / 1024 AS InternalObjectsAllocMB
FROM sys.dm_db_session_space_usage su
INNER JOIN sys.dm_exec_sessions s
    ON su.session_id = s.session_id
WHERE (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) > 0
ORDER BY (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    PLAN CACHE DISTRIBUTION & AD-HOC BLOAT
-------------------------------------------------------------------------------
.PURPOSE
    Identify plan cache memory allocation and potential ad-hoc cache pollution.
-----------------------------------------------------------------------------*/

SELECT
    objtype,
    COUNT(*) AS PlanCount,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS CacheSizeMB,
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS SingleUsePlans,
    SUM(CASE WHEN usecounts = 1 THEN CAST(size_in_bytes AS BIGINT) ELSE 0 END) / 1024 / 1024 AS SingleUseSizeMB
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY CacheSizeMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    HIGH-IMPACT MISSING INDEX RECOMMENDATIONS
-------------------------------------------------------------------------------
.PURPOSE
    Identify high-impact missing indexes that could relieve active CPU or I/O pressure.
-----------------------------------------------------------------------------*/

SELECT TOP (10)
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
    SECTION 11
    PARALLELISM & WORKLOAD CONFIGURATION
-------------------------------------------------------------------------------
.PURPOSE
    Review server-level parallelism thresholds affecting query compilation.
-----------------------------------------------------------------------------*/

SELECT
    name,
    value_in_use,
    description
FROM sys.configurations
WHERE name IN
(
    'max degree of parallelism',
    'cost threshold for parallelism',
    'optimize for ad hoc workloads',
    'min server memory (MB)',
    'max server memory (MB)'
);
GO

/*-----------------------------------------------------------------------------
    SECTION 12
    TOP ACTIVE REQUEST PLANS (SAFE SAMPLE)
-------------------------------------------------------------------------------
.PURPOSE
    Safely retrieve query execution plans for up to 5 longest-running active requests.
-----------------------------------------------------------------------------*/

SELECT TOP (5)
    r.session_id,
    r.cpu_time AS CPUTimeMs,
    r.total_elapsed_time AS ElapsedTimeMs,
    DB_NAME(r.database_id) AS DatabaseName,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS StatementText,
    qp.query_plan
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) qp
WHERE r.session_id > 50
  AND r.session_id <> @@SPID
ORDER BY r.total_elapsed_time DESC
OPTION (MAXDOP 1);
GO

/*-----------------------------------------------------------------------------
    SECTION 13
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    Provide a unified first-response dashboard across critical metrics.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE session_id > 50 AND session_id <> @@SPID) AS ActiveUserRequests,
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id <> 0) AS BlockedSessions,
    (SELECT SUM(runnable_tasks_count) FROM sys.dm_os_schedulers WHERE scheduler_id < 255) AS SchedulersRunnableTasks,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants WHERE grant_time IS NULL) AS WaitingMemoryGrants,
    (SELECT COUNT(*) FROM sys.dm_db_missing_index_details) AS MissingIndexRecommendations,
    (SELECT COUNT(*) FROM sys.dm_exec_cached_plans WHERE objtype = 'Adhoc' AND usecounts = 1) AS SingleUseAdhocPlans;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
IDENTIFIED SYMPTOM                  ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
High SOS_SCHEDULER_YIELD / CPU      --> Open Toolkit CPU.sql
High PAGEIOLATCH_* / Storage stalls --> Open Toolkit IO.sql
High LCK_M_* / Active Blockers      --> Open Toolkit Blocking.sql
Waiting Memory Grants / Low PLE     --> Open Toolkit Memory.sql
TempDB Space Exhaustion / Spills    --> Open Toolkit TempDB.sql
Specific Slow Query / Sniffing      --> Open Toolkit Query Performance.sql
High Ad-Hoc Cache Footprint         --> Open Toolkit Plan Cache.sql
AG Synchronization Lag / Disconnect --> Open Toolkit Always On.sql
******************************************************************************/
