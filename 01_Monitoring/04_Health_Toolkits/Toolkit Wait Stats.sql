/******************************************************************************
SQL SERVER WAIT STATISTICS HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

PURPOSE

This toolkit provides a structured approach for investigating
performance issues through SQL Server wait statistics.

SQL Server spends most of its lifetime waiting.

The goal is to determine:

    • Where SQL Server spends time waiting
    • Whether bottlenecks exist
    • Which subsystem is responsible
    • Which toolkit should be investigated next

AREAS COVERED

1. Top Waits Overview
2. Signal vs Resource Waits
3. CPU Related Waits
4. Parallelism Waits
5. Memory Related Waits
6. Physical I/O Waits
7. Transaction Log Waits
8. Lock Waits
9. Latch Waits
10. TempDB Related Waits
11. Worker Thread Waits
12. Network Waits
13. HADR / AG Waits
14. Wait Categorization
15. Dominant Wait Analysis
16. Executive Summary

WHEN TO USE THIS TOOLKIT

Use this toolkit when:

    • SQL Server appears slow
    • Root cause is unknown
    • Performance degradation is reported
    • CPU appears high
    • Memory pressure is suspected
    • Storage latency is suspected
    • Blocking is suspected

RECOMMENDED TROUBLESHOOTING FLOW

Step 1
-------
Review Executive Summary

Step 2
-------
Review Top Waits

Step 3
-------
Determine Dominant Category

    CPU
    Memory
    IO
    Locking
    Network
    HADR
    Parallelism

Step 4
-------
Open corresponding Health Toolkit

******************************************************************************/

/*----------------------------------*----------------------------------*---------
    SECTION 1
    TOP WAITS OVERVIEW
-------------------------------------------------------------------------------

.PURPOSE

    Identify the largest waits accumulated by SQL Server.

.WHY THIS MATTERS

    Wait statistics usually reveal the primary bottleneck.

.HEALTHY

    Waits align with workload characteristics.

.WARNING

    One wait category dominates total wait time.

.NEXT ACTIONS

    Review wait-specific sections below.

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
    SECTION 2
    SIGNAL VS RESOURCE WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Determine whether waits are CPU-related or resource-related.

.WHY THIS MATTERS

    Signal waits often indicate CPU scheduler pressure.

.HEALTHY

    Signal waits are relatively low.

.WARNING

    Signal waits represent a large percentage of total waits.

.POSSIBLE CAUSES

    CPU saturation.
    Runnable queue pressure.

.NEXT ACTIONS

    Review CPU Health Toolkit.

-------------------------------------------------------------------------------*/

SELECT
    SUM(wait_time_ms) AS TotalWaitMs,
    SUM(signal_wait_time_ms) AS TotalSignalWaitMs,
    CAST
    (
        100.0 * SUM(signal_wait_time_ms)
        / NULLIF(SUM(wait_time_ms),0)
        AS DECIMAL(10,2)
    ) AS SignalWaitPercentage
FROM sys.dm_os_wait_stats;

GO

/*-------------------------------------------------------------------------------
    SECTION 3
    CPU RELATED WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify waits associated with CPU pressure.

.KEY WAITS

    SOS_SCHEDULER_YIELD

    THREADPOOL

.HEALTHY

    Present but not dominant.

.WARNING

    Consistently among top waits.

.NEXT ACTIONS

    Review Health CPU Toolkit.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type IN
(
    'SOS_SCHEDULER_YIELD',
    'THREADPOOL'
);

GO

/*-------------------------------------------------------------------------------
    SECTION 4
    PARALLELISM WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify waits associated with parallel query execution.

.KEY WAITS

    CXPACKET

    CXCONSUMER

.HEALTHY

    Present but not dominant.

.WARNING

    Top waits in environment.

.NEXT ACTIONS

    Review MAXDOP configuration.
    Review Health CPU Toolkit.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type IN
(
    'CXPACKET',
    'CXCONSUMER'
);

GO

/*-------------------------------------------------------------------------------
    SECTION 5
    MEMORY RELATED WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify waits associated with memory pressure.

.KEY WAITS

    RESOURCE_SEMAPHORE

    MEMORY_ALLOCATION_EXT

.HEALTHY

    Rarely encountered.

.WARNING

    Significant wait durations.

.NEXT ACTIONS

    Review Health Memory Toolkit.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type IN
(
    'RESOURCE_SEMAPHORE',
    'MEMORY_ALLOCATION_EXT'
);

GO

/*-------------------------------------------------------------------------------
    SECTION 6
    PHYSICAL I/O WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify waits associated with physical disk reads.

.KEY WAITS

    PAGEIOLATCH_SH

    PAGEIOLATCH_EX

.HEALTHY

    Present but not dominant.

.WARNING

    Among highest waits.

.POSSIBLE CAUSES

    Storage latency.
    Memory pressure.
    Large scans.

.NEXT ACTIONS

    Review Health IO Toolkit.
    Review Health Memory Toolkit.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGEIOLATCH%';

GO

/*-------------------------------------------------------------------------------
    SECTION 7
    TRANSACTION LOG WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify waits associated with transaction log writes.

.KEY WAITS

    WRITELOG

.HEALTHY

    Minimal contribution.

.WARNING

    Significant wait time.

.POSSIBLE CAUSES

    Slow log storage.
    Heavy write activity.

.NEXT ACTIONS

    Review Health IO Toolkit.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type = 'WRITELOG';

GO

/*-------------------------------------------------------------------------------
    SECTION 8
    LOCK WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify waits caused by blocking.

.KEY WAITS

    LCK_M_S

    LCK_M_U

    LCK_M_X

.HEALTHY

    Low contribution.

.WARNING

    High wait duration.

.NEXT ACTIONS

    Review Health Blocking Toolkit.

-------------------------------------------------------------------------------*/

SELECT
    wait_type,
    wait_time_ms,
    signal_wait_time_ms,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'LCK%'
ORDER BY wait_time_ms DESC;

GO

/*----------------------------------*----------------------------------*---------
    SECTION 9
    LATCH *AITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify in-memory contention.

.KEY WAITS

    PAGELATCH_SH

    PAGELATCH_EX

    PAGELATCH_UP

.WHY THIS MATTERS

    Unlike PAGEIOLATCH, PAGELATCH waits occur in memory.

.WARNING

    Excessive latch contention.

.POSSIBLE CAUSES

    TempDB allocation contention.

.NEXT ACTIONS

    Review Health TempDB Toolkit.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGELATCH%';

GO

/*-------------------------------------------------------------------------------
    SECTION 10
    TEMPDB RELATED WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Review waits commonly associated with TempDB bottlenecks.

.KEY WAITS

    PAGELATCH_UP

    PAGELATCH_EX

.HEALTHY

    Present but minor.

.WARNING

    Significant contention.

.NEXT ACTIONS

    Review Health TempDB Toolkit.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type IN
(
    'PAGELATCH_UP',
    'PAGELATCH_EX'
);

GO

/*-------------------------------------------------------------------------------
    SECTION 11
    WORKER THREAD WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify worker thread starvation.

.KEY WAITS

    THREADPOOL

.HEALTHY

    Rarely observed.

.WARNING

    Indicates worker thread shortage.

.POSSIBLE CAUSES

    Excessive blocking.
    Long-running queries.
    Excessive concurrency.

.NEXT ACTIONS

    Review CPU and Blocking toolkits.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type = 'THREADPOOL';

GO

/*-------------------------------------------------------------------------------
    SECTION 12
    NETWORK WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Identify network or client-side bottlenecks.

.KEY WAITS

    ASYNC_NETWORK_IO

.HEALTHY

    Minimal contribution.

.WARNING

    Significant wait time.

.POSSIBLE CAUSES

    Slow client application.
    Slow result consumption.

.NEXT ACTIONS

    Review consuming application.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type = 'ASYNC_NETWORK_IO';

GO

/*----------------------------------*--------------------------------------------
    SECTION 13
    HADR / AVAILABILITY GROUP WAITS
-------------------------------------------------------------------------------

.PURPOSE

    Review waits associated with Availability Groups.

.KEY WAITS

    HADR_%

.HEALTHY

    Expected AG-related waits.

.WARNING

    Excessive HADR waits.

.POSSIBLE CAUSES

    Network latency.
    Replica synchronization issues.

.NEXT ACTIONS

    Review Health AlwaysOn Toolkit.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'HADR%';

GO

/*-------------------------------------------------------------------------------
    SECTION 14
    WAIT CATEGORIZATION
-------------------------------------------------------------------------------

.PURPOSE

    Categorize waits into major performance domains.

.WHY THIS MATTERS

    Speeds up root cause identification.

.CATEGORIES

    CPU

    Memory

    Storage

    Locking

    Network

    Parallelism

    HADR

.NEXT ACTIONS

    Open corresponding Health Toolkit.

-------------------------------------------------------------------------------*/

SELECT TOP (50)
    wait_type,
    wait_time_ms
FROM sys.dm_os_wait_stats
ORDER BY wait_time_ms DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 15
    DOMINANT WAIT ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Identify the top waits consuming server time.

.WHY THIS MATTERS

    Usually reveals the primary bottleneck.

.HEALTHY

    Balanced distribution.

.WARNING

    One wait category dominates.

.NEXT ACTIONS

    Focus investigation on dominant category.

-------------------------------------------------------------------------------*/

WITH Waits AS
(
    SELECT
        wait_type,
        wait_time_ms,
        100.0 * wait_time_ms /
        SUM(wait_time_ms) OVER() AS WaitPct
    FROM sys.dm_os_wait_stats
)
SELECT TOP (10)
    wait_type,
    wait_time_ms,
    CAST(WaitPct AS DECIMAL(10,2)) AS WaitPct
FROM Waits
ORDER BY wait_time_ms DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 16
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------

.PURPOSE

    Provide a quick wait statistics assessment.

.HEALTHY ENVIRONMENT

    Balanced wait distribution.

    No dominant bottleneck category.

.INVESTIGATE

    CPU waits.

    Memory waits.

    IO waits.

    Lock waits.

    HADR waits.

.NEXT ACTIONS

    CPU:
        Review Health CPU Toolkit

    Memory:
        Review Health Memory Toolkit

    IO:
        Review Health IO Toolkit

    Blocking:
        Review Health Blocking Toolkit

-------------------------------------------------------------------------------*/

SELECT
(
    SELECT COUNT(*)
    FROM sys.dm_exec_requests
) AS ActiveRequests,

(
    SELECT SUM(wait_time_ms)
    FROM sys.dm_os_wait_stats
) AS TotalWaitTimeMs,

(
    SELECT SUM(signal_wait_time_ms)
    FROM sys.dm_os_wait_stats
) AS TotalSignalWaitTimeMs;

GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

CPU ISSUE

INDICATORS

    SOS_SCHEDULER_YIELD

    THREADPOOL

REVIEW

    Health CPU Toolkit

------------------------------------------------------------------------------
MEMORY ISSUE

INDICATORS

    RESOURCE_SEMAPHORE

    MEMORY_ALLOCATION_EXT

REVIEW

    Health Memory Toolkit

------------------------------------------------------------------------------
I/O ISSUE

INDICATORS

    PAGEIOLATCH%

    WRITELOG

    IO_COMPLETION

REVIEW

    Health IO Toolkit

------------------------------------------------------------------------------
BLOCKING ISSUE

INDICATORS

    LCK_M_%

REVIEW

    Health Blocking Toolkit

------------------------------------------------------------------------------
TEMPD B ISSUE

INDICATORS

    PAGELATCH_UP

    PAGELATCH_EX

REVIEW

    Health TempDB Toolkit

------------------------------------------------------------------------------
NETWORK ISSUE

INDICATORS

    ASYNC_NETWORK_IO

REVIEW

    Application Analysis

------------------------------------------------------------------------------
ALWAYS ON ISSUE

INDICATORS

    HADR_%

REVIEW

    Health AlwaysOn Toolkit

******************************************************************************
END OF WAIT STATISTICS HEALTH CHECK
******************************************************************************/