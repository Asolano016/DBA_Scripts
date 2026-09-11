/******************************************************************************
SQL SERVER BLOCKING & CONCURRENCY HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

PURPOSE

This toolkit provides a structured approach for investigating
blocking, locking and concurrency issues in SQL Server.

The goal is to determine whether performance degradation is caused by:

    • Blocking sessions
    • Long-running transactions
    • Lock contention
    • Lock escalation
    • Deadlocks
    • Isolation level configuration
    • Concurrency design issues

AREAS COVERED

1. Current Blocking Overview
2. Blocking Chains
3. Head Blockers
4. Blocked Requests
5. Blocking Query Plans
6. Current Locks
7. Lock Wait Analysis
8. Open Transactions
9. Long Running Transactions
10. Lock Escalation Indicators
11. Deadlock Information
12. Session Isolation Levels
13. Concurrency Configuration
14. Executive Summary

WHEN TO USE THIS TOOLKIT

Use this toolkit when:

    • Users report application slowness
    • Transactions appear hung
    • Lock waits are increasing
    • Deadlocks are occurring
    • Blocking is suspected

RECOMMENDED TROUBLESHOOTING FLOW

Step 1
-------
Review Executive Summary

Step 2
-------
Review Current Blocking

Step 3
-------
Identify Head Blocker

Step 4
-------
Review Transaction Activity

Step 5
-------
Review Lock Analysis

Step 6
-------
Review Deadlock Activity

******************************************************************************/

/*----------------------------------*----------------------------------*---------
    SECTION 1
    CURREN* BLOCKING OVERVIEW
---------------*----------------------------------*----------------------------

.PUR*OSE

    Identify sessions current*y being blocked.

.WHY THIS MATTERS

    This is usually the first indication of a concurrency issue.

.KEY METRICS

    session_id

    blocking_session_id

    wait_type

    wait_time

.HEALTHY

    No rows returned.

.WARNING

    Rows returned indicating active blocking.

.POSSIBLE CAUSES

    Long transactions.
    Missing indexes.
    Large updates.
    Application design issues.

.NEXT ACTIONS

    Review Sections 2 and 3.

-------------------------------------------------------------------------------*/

SELECT
    session_id,
    blocking_session_id,
    wait_type,
    wait_time,
    status,
    command
FROM sys.dm_exec_requests
WHERE blocking_session_id > 0
ORDER BY wait_time DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 2
    BLOCKING CHAINS
-------------------------------------------------------------------------------

.PURPOSE

    Visualize blocking relationships.

.WHY THIS MATTERS

    Helps identify the blocking hierarchy.

.HEALTHY

    No chain detected.

.WARNING

    Long blocking chains.

.NEXT ACTIONS

    Identify the Head Blocker.

-------------------------------------------------------------------------------*/

SELECT
    session_id,
    blocking_session_id,
    status,
    wait_type,
    wait_time
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0
ORDER BY blocking_session_id;

GO

/*-------------------------------------------------------------------------------
    SECTION 3
    HEAD BLOCKERS
-------------------------------------------------------------------------------

.PURPOSE

    Identify root blocking sessions.

.WHY THIS MATTERS

    Resolving the head blocker often resolves the entire chain.

.HEALTHY

    No head blockers.

.WARNING

    Sessions blocking multiple requests.

.NEXT ACTIONS

    Review execution plan and transaction activity.

-------------------------------------------------------------------------------*/

SELECT DISTINCT
    blocking_session_id AS HeadBlocker
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0
    AND blocking_session_id NOT IN
    (
        SELECT session_id
        FROM sys.dm_exec_requests
        WHERE blocking_session_id > 0
    );

GO

/*-------------------------------------------------------------------------------
    SECTION 4
    BLOCKED REQUEST DETAILS
-------------------------------------------------------------------------------

.PURPOSE

    Show detailed information for blocked requests.

.WHY THIS MATTERS

    Helps determine impact and severity.

.WARNING

    High wait times.

.NEXT ACTIONS

    Review root blocker.

-------------------------------------------------------------------------------*/

SELECT
    r.session_id,
    r.blocking_session_id,
    r.wait_time,
    r.wait_type,
    DB_NAME(r.database_id) AS DatabaseName,
    t.text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id > 0
ORDER BY r.wait_time DESC;

GO

/*----------------------------------*----------------------------------*---------
    SECTION 5
    BLOCKING QUERY PLANS
-------------------------------------------------------------------------------

.PURPOSE

    Retrieve execution plans for blocking sessions.

.WHY THIS MATTERS

    Blocking often originates from inefficient plans.

.KEY OPERATORS

    Table Scan
    Index Scan
    Large Update
    Merge Operations

.WARNING

    Large scans and wide updates.

.NEXT ACTIONS

    Review indexes and predicates.

-------------------------------------------------------------------------------*/

SELECT
    r.session_id,
    t.text,
    qp.query_plan
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) qp
WHERE r.session_id IN
(
    SELECT DISTINCT blocking_session_id
    FROM sys.dm_exec_requests
    WHERE blocking_session_id > 0
)
OPTION(MAXDOP 1);

GO

/*-------------------------------------------------------------------------------
    SECTION 6
    CURRENT LOCKS
-------------------------------------------------------------------------------

.PURPOSE

    Review active locks.

.WHY THIS MATTERS

    Helps determine lock types and affected resources.

.KEY METRICS

    resource_type

    request_mode

.HEALTHY

    Expected lock activity.

.WARNING

    Excessive object and table locks.

.NEXT ACTIONS

    Review lock escalation.

-------------------------------------------------------------------------------*/

SELECT
    request_session_id,
    resource_type,
    request_mode,
    request_status
FROM sys.dm_tran_locks
ORDER BY request_session_id;

GO

/*-------------------------------------------------------------------------------
    SECTION 7
    LOCK WAIT ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Review locking-related wait statistics.

.WHY THIS MATTERS

    Lock waits often reveal underlying concurrency issues.

.KEY WAITS

    LCK_M_S

    LCK_M_U

    LCK_M_X

.HEALTHY

    Present but not dominant.

.WARNING

    Dominant lock waits.

.NEXT ACTIONS

    Review blocking sessions.

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

/*-------------------------------------------------------------------------------
    SECTION 8
    OPEN TRANSACTIONS
-------------------------------------------------------------------------------

.PURPOSE

    Identify active transactions.

.WHY THIS MATTERS

    Open transactions frequently cause blocking.

.HEALTHY

    Transactions complete quickly.

.WARNING

    Transactions remain open unnecessarily.

.NEXT ACTIONS

    Review application behavior.

-------------------------------------------------------------------------------*/

DBCC OPENTRAN;

GO


/*-------------------------------------------------------------------------------
    SECTION 9
    LONG RUNNING TRANSACTIONS
-------------------------------------------------------------------------------

.PURPOSE

    Identify transactions active for long periods.

.WHY THIS MATTERS

    Long transactions often drive blocking incidents.

.WARNING

    Transactions active for minutes or hours.

.NEXT ACTIONS

    Review transaction design.

-------------------------------------------------------------------------------*/

SELECT
    transaction_id,
    transaction_begin_time,
    DATEDIFF(MINUTE, transaction_begin_time, GETDATE()) AS MinutesOpen
FROM sys.dm_tran_active_transactions
ORDER BY transaction_begin_time;

GO

/*-------------------------------------------------------------------------------
    SECTION 10
    LOCK ESCALATION INDICATORS
-------------------------------------------------------------------------------

.PURPOSE

    Identify lock escalation events.

.WHY THIS MATTERS

    Escalation can dramatically increase blocking.

.WARNING

    Large number of OBJECT locks.

.POSSIBLE CAUSES

    Large updates.
    Bulk operations.

.NEXT ACTIONS

    Review transaction sizing.

-------------------------------------------------------------------------------*/

SELECT
    resource_type,
    request_mode,
    COUNT(*) AS LockCount
FROM sys.dm_tran_locks
GROUP BY
    resource_type,
    request_mode
ORDER BY LockCount DESC;

GO

/*-------------------------------------------------------------------------------
    SECTION 11
    DEADLOCK INFORMATION
-------------------------------------------------------------------------------

.PURPOSE

    Review deadlock-related information.

.WHY THIS MATTERS

    Deadlocks indicate competing resource acquisition.

.HEALTHY

    No recent deadlocks.

.WARNING

    Frequent deadlock occurrences.

.NEXT ACTIONS

    Review Extended Events session.
    Review application locking order.

-------------------------------------------------------------------------------*/

SELECT *
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Number of Deadlocks/sec';

GO

/*-------------------------------------------------------------------------------
    SECTION 12
    SESSION ISOLATION LEVELS
-------------------------------------------------------------------------------

.PURPOSE

    Review transaction isolation levels.

.WHY THIS MATTERS

    Isolation levels directly impact locking behavior.

.HEALTHY

    Consistent workload-appropriate levels.

.WARNING

    Excessive SERIALIZABLE usage.

.POSSIBLE CAUSES

    Application design.

.NEXT ACTIONS

    Review concurrency requirements.

-------------------------------------------------------------------------------*/

SELECT
    session_id,
    transaction_isolation_level
FROM sys.dm_exec_sessions
WHERE is_user_process = 1;

GO

/*-------------------------------------------------------------------------------
    SECTION 13
    CONCURRENCY CONFIGURATION
-------------------------------------------------------------------------------

.PURPOSE

    Review row-versioning configuration.

.WHY THIS MATTERS

    Snapshot technologies can reduce blocking.

.KEY SETTINGS

    READ_COMMITTED_SNAPSHOT

    ALLOW_SNAPSHOT_ISOLATION

.HEALTHY

    Configuration aligns with workload requirements.

.WARNING

    Blocking-heavy environments without row-versioning.

.NEXT ACTIONS

    Evaluate snapshot isolation.

-------------------------------------------------------------------------------*/

SELECT
    name,
    is_read_committed_snapshot_on,
    snapshot_isolation_state_desc
FROM sys.databases;

GO

/*-------------------------------------------------------------------------------
    SECTION 14
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------

.PURPOSE

    Provide a quick concurrency health assessment.

.HEALTHY ENVIRONMENT

    No blocking chains.

    No excessive lock waits.

    No long-running transactions.

    No deadlock activity.

.INVESTIGATE

    Blocking sessions.

    Long transactions.

    LCK waits.

    Deadlocks.

.NEXT ACTIONS

    Blocking:
        Review Sections 1-5

    Locks:
        Review Sections 6-10

    Isolation:
        Review Sections 12-13

-------------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*)
     FROM sys.dm_exec_requests
     WHERE blocking_session_id > 0) AS BlockedSessions,

    (SELECT COUNT(*)
     FROM sys.dm_tran_locks) AS ActiveLocks,

    (SELECT COUNT(*)
     FROM sys.dm_tran_active_transactions) AS ActiveTransactions;

GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

ACTIVE BLOCKING

INDICATORS

    blocking_session_id > 0

    LCK waits increasing

REVIEW

    Sections 1-5

------------------------------------------------------------------------------
LONG TRANSACTION

INDICATORS

    Open transactions

    Transactions active for long periods

REVIEW

    Sections 8 and 9

------------------------------------------------------------------------------
LOCK ESCALATION

INDICATORS

    OBJECT locks

    TABLE locks

    Widespread blocking

REVIEW

    Sections 6 and 10

------------------------------------------------------------------------------
DEADLOCK ISSUE

INDICATORS

    Deadlocks/sec

REVIEW

    Section 11

------------------------------------------------------------------------------
ISOLATION LEVEL ISSUE

INDICATORS

    Excessive locking

    SERIALIZABLE usage

REVIEW

    Sections 12 and 13

------------------------------------------------------------------------------
NOT A BLOCKING ISSUE

INDICATORS

    No blocked sessions

    No lock waits

    No long transactions

REVIEW

    Health CPU Toolkit

    Health Memory Toolkit

    Health IO Toolkit

    Health Wait Statistics Toolkit

******************************************************************************
END OF BLOCKING & CONCURRENCY HEALTH CHECK
******************************************************************************/