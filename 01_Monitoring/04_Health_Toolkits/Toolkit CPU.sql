/******************************************************************************
SQL SERVER CPU HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

PURPOSE

This toolkit provides a structured approach for investigating
CPU-related performance issues in SQL Server.

AREAS COVERED

1. SQL Server CPU Utilization
2. Current CPU Pressure Validation
3. Active CPU Consumers
4. Historical Top CPU Queries
5. Top CPU Stored Procedures
6. CPU Usage by Database
7. CPU Intensive Execution Plans
8. Scheduler Health
9. Runnable Queue Analysis
10. SOS_SCHEDULER_YIELD Analysis
11. Processor Queue Analysis
12. Parallelism Configuration
13. Parallelism Waits
14. Compilation Activity
15. Plan Cache Efficiency
16. Missing Index Impact
17. CPU Wait Statistics
18. Executive Summary

HOW TO USE

Recommended troubleshooting flow:

    1. Executive Summary
    2. CPU Utilization
    3. Scheduler Health
    4. Runnable Queues
    5. Active CPU Consumers
    6. Historical CPU Consumers
    7. Wait Analysis
    8. Parallelism
    9. Compilation Analysis
    10. Plan Cache Review

******************************************************************************/

/*-------------------------------------------------------------------------------
    SECTION 1
    SQL SERVER CPU UTILIZATION
-------------------------------------------------------------------------------

.PURPOSE

    Obtain a quick snapshot of SQL Server CPU utilization.

.WHY THIS MATTERS

    Helps determine whether SQL Server is actively consuming CPU.

.KEY METRICS

    SQLProcessUtilization

    SystemIdle

.HEALTHY

    SQLProcessUtilization stable.

    SystemIdle comfortably above zero.

.WARNING

    SQLProcessUtilization remains consistently high.

    SystemIdle remains consistently low.

.POSSIBLE CAUSES

    Expensive queries.
    Parallelism.
    Missing indexes.
    Compilation pressure.

.NEXT ACTIONS

    Review Sections 3, 4 and 8.

-------------------------------------------------------------------------------*/

SELECT TOP (1)
    record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'INT') AS SystemIdle,
    record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'INT') AS SQLProcessUtilization
FROM
(
    SELECT CAST(record AS XML) AS record
    FROM sys.dm_os_ring_buffers
    WHERE ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
        AND record LIKE '%<SystemHealth>%'
) x
ORDER BY record.value('(./Record/@id)[1]', 'INT') DESC;
GO

/*-------------------------------------------------------------------------------
    SECTION 2
    CURRENT CPU PRESSURE VALIDATION
-------------------------------------------------------------------------------

.PURPOSE

    Determine whether SQL Server is truly CPU bound.

.WHY THIS MATTERS

    High CPU usage alone does not necessarily indicate CPU pressure.

.KEY METRICS

    RunnableTasks

.HEALTHY

    RunnableTasks remain low.

.WARNING

    RunnableTasks continuously growing.

.POSSIBLE CAUSES

    CPU saturation.
    Excessive parallelism.
    Excessive workload concurrency.

.NEXT ACTIONS

    Review Sections 8, 9 and 10.

-------------------------------------------------------------------------------*/

SELECT
    SUM(runnable_tasks_count) AS RunnableTasks,
    SUM(current_tasks_count) AS CurrentTasks,
    SUM(active_workers_count) AS ActiveWorkers
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255;

GO

/*-------------------------------------------------------------------------------
    SECTION 3
    ACTIVE CPU CONSUMERS
-------------------------------------------------------------------------------

.PURPOSE

    Show currently executing requests consuming CPU.

.WHY THIS MATTERS

    Useful during active incidents or performance degradation.

.KEY METRICS

    cpu_time

    total_elapsed_time

    wait_type

.HEALTHY

    CPU usage distributed across multiple sessions.

.WARNING

    One or a few sessions dominate CPU consumption.

.POSSIBLE CAUSES

    Runaway queries.
    Large scans.
    Poor execution plans.

.NEXT ACTIONS

    Capture execution plans.
    Review wait types.

-------------------------------------------------------------------------------*/

SELECT
    r.session_id,
    r.status,
    r.cpu_time,
    r.total_elapsed_time,
    r.command,
    r.wait_type,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS DatabaseName,
    t.text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id > 50
ORDER BY r.cpu_time DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 4
    HISTORICAL TOP CPU QUERIES
-------------------------------------------------------------------------------

.PURPOSE

    Identify historically expensive CPU consumers.

.WHY THIS MATTERS

    A small number of queries often account for most CPU usage.

.KEY METRICS

    TotalCPUms

    AvgCPUms

    ExecutionCount

.HEALTHY

    CPU usage evenly distributed across workload.

.WARNING

    Small number of queries dominate total CPU.

.POSSIBLE CAUSES

    Missing indexes.
    Poor plans.
    Large scans.

.NEXT ACTIONS

    Review execution plans.
    Review indexes.

-------------------------------------------------------------------------------*/

SELECT TOP (20)
    qs.execution_count,
    qs.total_worker_time / 1000 AS TotalCPUms,
    (qs.total_worker_time / qs.execution_count) / 1000 AS AvgCPUms,
    qs.total_logical_reads,
    qs.total_logical_writes,
    SUBSTRING
    (
        st.text,
        (qs.statement_start_offset/2)+1,
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
ORDER BY qs.total_worker_time DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 5
    TOP CPU STORED PROCEDURES
-------------------------------------------------------------------------------

.PURPOSE

    Identify stored procedures consuming the most CPU.

.WHY THIS MATTERS

    Stored procedures often account for the majority of OLTP workload.

.HEALTHY

    CPU utilization distributed across procedures.

.WARNING

    Same procedures repeatedly dominate CPU usage.

.POSSIBLE CAUSES

    Poor procedure design.
    Missing indexes.
    Parameter sniffing.

.NEXT ACTIONS

    Capture execution plans.
    Review statistics.
    Review indexes.

-------------------------------------------------------------------------------*/

SELECT TOP (20)
    DB_NAME(database_id) AS DatabaseName,
    OBJECT_NAME(object_id, database_id) AS ProcedureName,
    cached_time,
    last_execution_time,
    execution_count,
    total_worker_time / 1000 AS TotalCPUms,
    (total_worker_time / execution_count) / 1000 AS AvgCPUms
FROM sys.dm_exec_procedure_stats
ORDER BY total_worker_time DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 6
    CPU USAGE BY DATABASE
-------------------------------------------------------------------------------

.PURPOSE

    Estimate CPU utilization by database.

.WHY THIS MATTERS

    Helps identify databases responsible for CPU pressure.

.HEALTHY

    CPU utilization aligns with expected workload.

.WARNING

    A single database dominates CPU consumption.

.POSSIBLE CAUSES

    Heavy reporting workload.
    Batch processing.
    Poorly tuned queries.

.NEXT ACTIONS

    Focus tuning efforts on affected databases.

-------------------------------------------------------------------------------*/

SELECT
    DB_NAME(CAST(pa.value AS INT)) AS DatabaseName,
    SUM(qs.total_worker_time) / 1000 AS TotalCPUms
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa
WHERE pa.attribute = 'dbid'
GROUP BY CAST(pa.value AS INT)
ORDER BY TotalCPUms DESC;
GO


/*-------------------------------------------------------------------------------
    SECTION 7
    CPU INTENSIVE EXECUTION PLANS
-------------------------------------------------------------------------------

.PURPOSE

    Retrieve execution plans for active CPU consumers.

.WHY THIS MATTERS

    CPU issues are usually identified in the execution plan.

.KEY OPERATORS

    Table Scan
    Index Scan
    Sort
    Hash Match
    Parallelism

.WARNING

    Large scans and expensive operators.

.NEXT ACTIONS

    Compare estimated versus actual rows.
    Review indexing strategy.

-------------------------------------------------------------------------------*/

SELECT
    r.session_id,
    r.cpu_time,
    t.text,
    qp.query_plan
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) qp
WHERE r.session_id > 50
OPTION (MAXDOP 1);

GO

/*-------------------------------------------------------------------------------
    SECTION 8
    SCHEDULER HEALTH
-------------------------------------------------------------------------------

.PURPOSE

    Review SQL Server scheduler activity.

.WHY THIS MATTERS

    Scheduler pressure is one of the strongest indicators of CPU bottlenecks.

.KEY METRICS

    runnable_tasks_count

    current_tasks_count

    active_workers_count

.HEALTHY

    Runnable queues remain low.

.WARNING

    High runnable task counts across schedulers.

.POSSIBLE CAUSES

    CPU saturation.
    Parallelism.
    Excessive workload.

.NEXT ACTIONS

    Review Sections 9 and 10.

-------------------------------------------------------------------------------*/

SELECT
    scheduler_id,
    cpu_id,
    status,
    current_tasks_count,
    runnable_tasks_count,
    active_workers_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255
ORDER BY runnable_tasks_count DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 9
    RUNNABLE QUEUE ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Identify schedulers experiencing CPU pressure.

.WHY THIS MATTERS

    Runnable tasks waiting for CPU are one of the best indicators
    of CPU bottlenecks.

.HEALTHY

    RunnableTasks close to zero.

.WARNING

    RunnableTasks continuously above zero.

.POSSIBLE CAUSES

    CPU saturation.
    Parallel workloads.
    Excessive concurrent activity.

.NEXT ACTIONS

    Review active CPU consumers.
    Review parallelism configuration.

-------------------------------------------------------------------------------*/

SELECT
    scheduler_id,
    runnable_tasks_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255
    AND runnable_tasks_count > 0
ORDER BY runnable_tasks_count DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 10
    SOS_SCHEDULER_YIELD ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Detect CPU-bound workloads.

.WHY THIS MATTERS

    SOS_SCHEDULER_YIELD is one of the most common waits
    associated with CPU pressure.

.HEALTHY

    Present but not dominant.

.WARNING

    One of the highest waits in the system.

.POSSIBLE CAUSES

    CPU bottlenecks.
    Large scans.
    Missing indexes.

.NEXT ACTIONS

    Review Sections 4, 8 and 9.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type = 'SOS_SCHEDULER_YIELD';

GO

/*-------------------------------------------------------------------------------
    SECTION 11
    PROCESSOR QUEUE ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Review pending requests waiting for schedulers.

.WHY THIS MATTERS

    High queue lengths indicate CPU pressure.

.HEALTHY

    Low pending task counts.

.WARNING

    Large pending task counts.

.POSSIBLE CAUSES

    CPU saturation.
    Excessive concurrency.

.NEXT ACTIONS

    Review scheduler pressure.

-------------------------------------------------------------------------------*/

SELECT
    scheduler_id,
    pending_disk_io_count,
    current_tasks_count,
    runnable_tasks_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255
ORDER BY runnable_tasks_count DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 12
    PARALLELISM CONFIGURATION
-------------------------------------------------------------------------------

.PURPOSE

    Review server-level parallelism configuration.

.KEY SETTINGS

    max degree of parallelism

    cost threshold for parallelism

.HEALTHY

    Settings aligned with workload requirements.

.WARNING

    MAXDOP misconfigured.

    Cost Threshold too low.

.POSSIBLE CAUSES

    Legacy configurations.
    Default settings.

.NEXT ACTIONS

    Review parallelism waits.

-------------------------------------------------------------------------------*/

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

/*-------------------------------------------------------------------------------
    SECTION 13
    PARALLELISM WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Evaluate waits caused by parallel execution.

.KEY WAITS

    CXPACKET

    CXCONSUMER

.HEALTHY

    Present but not dominant.

.WARNING

    Top waits in environment.

.POSSIBLE CAUSES

    Over-parallelization.
    Poor execution plans.

.NEXT ACTIONS

    Review MAXDOP configuration.
    Review execution plans.

-------------------------------------------------------------------------------*/

SELECT
    wait_type,
    wait_time_ms,
    signal_wait_time_ms,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('CXPACKET', 'CXCONSUMER');

GO

/*-------------------------------------------------------------------------------
    SECTION 14
    COMPILATION ACTIVITY
-------------------------------------------------------------------------------

.PURPOSE

    Evaluate compilation-related CPU overhead.

.WHY THIS MATTERS

    Excessive compilations increase CPU consumption.

.KEY METRICS

    Batch Requests/sec

    SQL Compilations/sec

    SQL Re-Compilations/sec

.HEALTHY

    Batch Requests significantly exceed Compilations.

.WARNING

    High compilation rates.

.POSSIBLE CAUSES

    Adhoc workloads.
    Recompile hints.
    Poor parameterization.

.NEXT ACTIONS

    Review plan cache efficiency.

-------------------------------------------------------------------------------*/

SELECT
    counter_name,
    cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name IN
(
    'Batch Requests/sec',
    'SQL Compilations/sec',
    'SQL Re-Compilations/sec'
);

GO

/*-------------------------------------------------------------------------------
    SECTION 15
    PLAN CACHE EFFICIENCY
-------------------------------------------------------------------------------

.PURPOSE

    Identify plan cache inefficiencies.

.WHY THIS MATTERS

    Excessive compilations often result from poor plan reuse.

.HEALTHY

    Majority of plans reused.

.WARNING

    Large number of Adhoc plans.

.POSSIBLE CAUSES

    Literal values.
    Poor parameterization.

.NEXT ACTIONS

    Review Optimize for Ad Hoc Workloads.
    Review application design.

-------------------------------------------------------------------------------*/

SELECT
    objtype,
    COUNT(*) AS Plans,
    SUM(size_in_bytes) / 1024 / 1024 AS CacheMB
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY CacheMB DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 16
    MISSING INDEX IMPACT
-------------------------------------------------------------------------------

.PURPOSE

    Identify missing indexes contributing to CPU overhead.

.WHY THIS MATTERS

    Missing indexes force SQL Server to perform more reads,
    resulting in higher CPU utilization.

.HEALTHY

    Few high-impact missing index recommendations.

.WARNING

    High user seeks and impact percentages.

.POSSIBLE CAUSES

    Untuned workload.
    New application functionality.

.NEXT ACTIONS

    Review index recommendations carefully.

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
    SECTION 17
    CPU WAIT STATISTICS
-------------------------------------------------------------------------------

.PURPOSE

    Review the top waits affecting CPU-related performance.

.WHY THIS MATTERS

    High CPU is frequently a symptom rather than the root cause.

.HEALTHY

    Waits align with workload characteristics.

.WARNING

    CPU-related waits dominate the system.

.POSSIBLE CAUSES

    CPU pressure.
    Parallelism.
    Excessive workload volume.

.NEXT ACTIONS

    Review wait categories and correlate with workload patterns.

-------------------------------------------------------------------------------*/

SELECT TOP (25)
    wait_type,
    wait_time_ms,
    signal_wait_time_ms,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE 'SLEEP%'
ORDER BY wait_time_ms DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 18
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------

.PURPOSE

    Provide a quick CPU health assessment.

.HEALTHY ENVIRONMENT

    Stable SQLProcessUtilization.

    Low runnable queues.

    No scheduler pressure.

    CPU workload evenly distributed.

    No excessive compilations.

.INVESTIGATE

    High CPU utilization.

    High runnable queues.

    High SOS_SCHEDULER_YIELD.

    High CXPACKET/CXCONSUMER.

    High compilations.

.NEXT ACTIONS

    Active CPU:
        Review Sections 3 and 4.

    Scheduler Pressure:
        Review Sections 8, 9 and 10.

    Parallelism:
        Review Sections 12 and 13.

    Plan Cache:
        Review Sections 14 and 15.

-------------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*)
     FROM sys.dm_exec_requests
     WHERE session_id > 50) AS ActiveRequests,

    (SELECT SUM(runnable_tasks_count)
     FROM sys.dm_os_schedulers
     WHERE scheduler_id < 255) AS RunnableTasks,

    (SELECT value_in_use
     FROM sys.configurations
     WHERE name = 'max degree of parallelism') AS MAXDOP,

    (SELECT value_in_use
     FROM sys.configurations
     WHERE name = 'cost threshold for parallelism') AS CostThresholdForParallelism,

    (SELECT COUNT(*)
     FROM sys.dm_exec_cached_plans
     WHERE objtype = 'Adhoc') AS AdhocPlans;

GO


/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

CPU SATURATION

INDICATORS

    High SQLProcessUtilization

    High RunnableTasks

    High SOS_SCHEDULER_YIELD

REVIEW

    Sections 3, 4, 8, 9 and 10

------------------------------------------------------------------------------
PARALLELISM ISSUE

INDICATORS

    CXPACKET

    CXCONSUMER

    High CPU

REVIEW

    Sections 12 and 13

------------------------------------------------------------------------------
COMPILATION ISSUE

INDICATORS

    High SQL Compilations/sec

    High SQL Re-Compilations/sec

    Large Adhoc Cache

REVIEW

    Sections 14 and 15

------------------------------------------------------------------------------
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