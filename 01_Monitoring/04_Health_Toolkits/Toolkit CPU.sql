/******************************************************************************
SQL SERVER CPU HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a structured approach for investigating CPU-related
performance bottlenecks, scheduler pressure, parallelism issues, and compilation overhead.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. SQL Server CPU Utilization History (Recent Minutes)
2. Scheduler Health & Runnable Task Queues
3. Active CPU Consuming Requests
4. Historical Top CPU Queries (Statement Level)
5. Top CPU Stored Procedures
6. CPU Usage Aggregation by Database
7. Execution Plans for Active CPU Consumers
8. Scheduler Detailed Worker Distribution
9. SOS_SCHEDULER_YIELD & Yield Analysis
10. Schedulers with Pending Disk I/O
11. Server Parallelism Configuration (MAXDOP / Cost Threshold)
12. Parallelism Wait Analysis (CXPACKET vs CXCONSUMER)
13. SQL Compilations vs Batch Requests (Cumulative)
14. Plan Cache Efficiency & Ad-Hoc Bloat
15. Missing Index Impact on CPU
16. CPU-Related Filtered Wait Statistics
17. Executive Summary & Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Executive Summary & CPU Utilization
    2. Scheduler Health & Runnable Queues
    3. Active CPU Requests & Historical Top Queries
    4. Parallelism & Compilation Efficiency

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    SQL SERVER CPU UTILIZATION HISTORY (RECENT MINUTES)
-------------------------------------------------------------------------------
.PURPOSE
    Extract recent CPU utilization percentages for SQL Server and System Idle.

.WHY THIS MATTERS
    Differentiates whether high CPU is caused by SQL Server or external OS processes.

.KEY METRICS
    SQLProcessUtilization
    OtherProcessUtilization
    SystemIdle
-----------------------------------------------------------------------------*/

DECLARE @ts_now BIGINT = (SELECT cpu_ticks / (cpu_ticks / ms_ticks) FROM sys.dm_os_sys_info);

SELECT TOP (10)
    DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS EventTime,
    record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'INT') AS SQLProcessUtilization,
    record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'INT') AS SystemIdle,
    100 - record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'INT')
        - record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'INT') AS OtherProcessUtilization
FROM
(
    SELECT
        [timestamp],
        CAST(record AS XML) AS record
    FROM sys.dm_os_ring_buffers
    WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
      AND record LIKE N'%<SystemHealth>%'
) AS rb
ORDER BY [timestamp] DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    SCHEDULER HEALTH & RUNNABLE TASK QUEUES
-------------------------------------------------------------------------------
.PURPOSE
    Determine whether SQL Server is actively CPU bound across schedulers.

.WHY THIS MATTERS
    Runnable tasks > 0 indicate threads waiting for CPU time slice.

.HEALTHY
    RunnableTasks is 0 or low single digits across schedulers.

.WARNING
    RunnableTasks continuously exceeds 1-2 per visible scheduler.
-----------------------------------------------------------------------------*/

SELECT
    SUM(runnable_tasks_count) AS TotalRunnableTasks,
    SUM(current_tasks_count) AS TotalCurrentTasks,
    SUM(active_workers_count) AS TotalActiveWorkers,
    SUM(work_queue_count) AS TotalWorkQueueCount
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255
  AND status = 'VISIBLE ONLINE';
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    ACTIVE CPU CONSUMING REQUESTS
-------------------------------------------------------------------------------
.PURPOSE
    Show currently executing requests consuming CPU time.
-----------------------------------------------------------------------------*/

SELECT
    r.session_id,
    r.status,
    r.cpu_time AS CPUTimeMs,
    r.total_elapsed_time AS ElapsedTimeMs,
    r.logical_reads AS LogicalReads,
    r.command,
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
ORDER BY r.cpu_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    HISTORICAL TOP CPU QUERIES (STATEMENT LEVEL)
-------------------------------------------------------------------------------
.PURPOSE
    Identify historically expensive queries by total CPU worker time.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_worker_time / 1000 AS TotalCPUms,
    (qs.total_worker_time / NULLIF(qs.execution_count, 0)) / 1000 AS AvgCPUms,
    qs.total_logical_reads AS TotalLogicalReads,
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
    SECTION 5
    TOP CPU STORED PROCEDURES
-------------------------------------------------------------------------------
.PURPOSE
    Identify stored procedures consuming the most CPU time.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    DB_NAME(database_id) AS DatabaseName,
    OBJECT_NAME(object_id, database_id) AS ProcedureName,
    cached_time,
    last_execution_time,
    execution_count,
    total_worker_time / 1000 AS TotalCPUms,
    (total_worker_time / NULLIF(execution_count, 0)) / 1000 AS AvgCPUms
FROM sys.dm_exec_procedure_stats
ORDER BY total_worker_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    CPU USAGE AGGREGATION BY DATABASE
-------------------------------------------------------------------------------
.PURPOSE
    Estimate CPU utilization aggregated across cached plans by database.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    COALESCE(DB_NAME(CAST(pa.value AS INT)), 'Ad-hoc / Prepared') AS DatabaseName,
    SUM(qs.total_worker_time) / 1000 AS TotalCPUms,
    SUM(qs.execution_count) AS TotalExecutions
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa
WHERE pa.attribute = 'dbid'
GROUP BY CAST(pa.value AS INT)
ORDER BY TotalCPUms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 7
    EXECUTION PLANS FOR ACTIVE CPU CONSUMERS
-------------------------------------------------------------------------------
.PURPOSE
    Retrieve execution plans for currently active queries consuming high CPU.
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
ORDER BY r.cpu_time DESC
OPTION (MAXDOP 1);
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    SCHEDULER DETAILED WORKER DISTRIBUTION
-------------------------------------------------------------------------------
.PURPOSE
    Review workload balance across visible online CPU schedulers.
-----------------------------------------------------------------------------*/

SELECT
    scheduler_id,
    cpu_id,
    status,
    is_online,
    current_tasks_count,
    runnable_tasks_count,
    active_workers_count,
    work_queue_count,
    pending_disk_io_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255
ORDER BY runnable_tasks_count DESC, scheduler_id;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    SOS_SCHEDULER_YIELD & YIELD ANALYSIS
-------------------------------------------------------------------------------
.PURPOSE
    Review SOS_SCHEDULER_YIELD waits indicating CPU-bound execution quantum loops.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type = 'SOS_SCHEDULER_YIELD';
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    SCHEDULERS WITH PENDING DISK I/O
-------------------------------------------------------------------------------
.PURPOSE
    Identify whether schedulers are blocked waiting on outstanding disk I/O requests.
-----------------------------------------------------------------------------*/

SELECT
    scheduler_id,
    pending_disk_io_count,
    current_tasks_count,
    runnable_tasks_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255
  AND pending_disk_io_count > 0
ORDER BY pending_disk_io_count DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 11
    SERVER PARALLELISM CONFIGURATION
-------------------------------------------------------------------------------
.PURPOSE
    Review server-level MAXDOP and Cost Threshold for Parallelism settings.
-----------------------------------------------------------------------------*/

SELECT
    name,
    value_in_use,
    description
FROM sys.configurations
WHERE name IN
(
    'max degree of parallelism',
    'cost threshold for parallelism'
);
GO

/*-----------------------------------------------------------------------------
    SECTION 12
    PARALLELISM WAIT ANALYSIS
-------------------------------------------------------------------------------
.PURPOSE
    Evaluate CXPACKET (coordinator/skew wait) and CXCONSUMER (normal parallel consumer).
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
    SECTION 13
    SQL COMPILATIONS VS BATCH REQUESTS (CUMULATIVE)
-------------------------------------------------------------------------------
.PURPOSE
    Inspect compilation ratios. Note: These values represent cumulative totals since startup.
-----------------------------------------------------------------------------*/

SELECT
    counter_name,
    cntr_value AS CumulativeCount
FROM sys.dm_os_performance_counters
WHERE counter_name IN
(
    'Batch Requests/sec',
    'SQL Compilations/sec',
    'SQL Re-Compilations/sec'
);
GO

/*-----------------------------------------------------------------------------
    SECTION 14
    PLAN CACHE EFFICIENCY & AD-HOC BLOAT
-------------------------------------------------------------------------------
.PURPOSE
    Identify plan cache memory distribution and single-use plan waste.
-----------------------------------------------------------------------------*/

SELECT
    objtype,
    COUNT(*) AS PlanCount,
    SUM(CAST(size_in_bytes AS BIGINT)) / 1024 / 1024 AS CacheMB,
    SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS SingleUsePlans
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY CacheMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 15
    MISSING INDEX IMPACT ON CPU
-------------------------------------------------------------------------------
.PURPOSE
    Identify missing indexes driving unnecessary table scans and CPU cycles.
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
    SECTION 16
    CPU-RELATED FILTERED WAIT STATISTICS
-------------------------------------------------------------------------------
.PURPOSE
    Inspect top actionable waits affecting CPU performance.
-----------------------------------------------------------------------------*/

SELECT TOP (15)
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN
(
    N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
    N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE', N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT',
    N'CLR_SEMAPHORE', N'CXCONSUMER', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
    N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'LAZYWRITER_SLEEP',
    N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE', N'REQUEST_FOR_DEADLOCK_SEARCH',
    N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_TASK', N'SLEEP_SYSTEMTASK', N'XE_DISPATCHER_WAIT',
    N'XE_TIMER_EVENT'
)
  AND wait_type NOT LIKE N'SLEEP_%'
  AND wait_type NOT LIKE N'PREEMPTIVE_%'
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 17
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    High-level CPU summary dashboard.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE session_id > 50 AND session_id <> @@SPID) AS ActiveRequests,
    (SELECT SUM(runnable_tasks_count) FROM sys.dm_os_schedulers WHERE scheduler_id < 255 AND status = 'VISIBLE ONLINE') AS RunnableTasks,
    (SELECT value_in_use FROM sys.configurations WHERE name = 'max degree of parallelism') AS MAXDOP,
    (SELECT value_in_use FROM sys.configurations WHERE name = 'cost threshold for parallelism') AS CostThresholdForParallelism,
    (SELECT COUNT(*) FROM sys.dm_exec_cached_plans WHERE objtype = 'Adhoc' AND usecounts = 1) AS SingleUseAdhocPlans;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
CPU BOTTLENECK SYMPTOM              ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
High RunnableTasks / SOS_SCHEDULER  --> Tune top queries (Section 4) & Missing Indexes (Section 15)
High CXPACKET with low CXCONSUMER   --> Evaluate MAXDOP / Cost Threshold (Section 11)
High Compilations / Adhoc bloat     --> Enable 'optimize for ad hoc workloads'
High SystemIdle, Low SQL Usage      --> Investigate external OS processes
******************************************************************************/

QUERY TUNING ISSUE

INDICATORS

    Few queries dominate TotalCPUms

    Large scans

    Expensive execution plans

REVIEW

    Sections 4 and 7

------------------------------------------------------------------------------
MISSING INDEX ISSUE

INDICATORS

    High logical reads

    High CPU

    Missing Index recommendations

REVIEW

    Section 16

------------------------------------------------------------------------------
CPU IS NOT THE ROOT CAUSE

INDICATORS

    CPU utilization appears high

    Runnable queues remain low

    SOS_SCHEDULER_YIELD not significant

REVIEW

    Memory Health Check

    IO Health Check

    Blocking Health Check

******************************************************************************
END OF CPU HEALTH CHECK
******************************************************************************/