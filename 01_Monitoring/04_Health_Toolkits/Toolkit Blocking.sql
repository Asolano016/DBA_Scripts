/******************************************************************************
SQL SERVER BLOCKING & CONCURRENCY HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a structured approach for investigating blocking chains,
idle head blockers with uncommitted transactions, lock escalation, deadlocks,
and transaction isolation level configurations.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Current Active Blocking Overview
2. Blocking Tree & Chain Hierarchy
3. Head Blockers (Including Sleeping / Idle Sessions)
4. Blocked Request Details (Statement Level)
5. Execution Plans for Active Blocking Sessions
6. Waiting Locks & Contention Summary
7. Lock-Related Wait Statistics (LCK_M_*)
8. Active Open Transactions Across Instance
9. Long-Running Active Transactions
10. Lock Summary by Resource Type & Mode (Escalation)
11. Deadlock Activity & Rate Overview
12. User Session Isolation Level Distribution
13. Database Snapshot / RCSI Configuration
14. Executive Summary & Concurrency Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Review Executive Summary & Current Blocking
    2. Identify Head Blocker (Check for Sleeping Sessions in Section 3)
    3. Review Blocked Statements & Execution Plans
    4. Review Open Transactions & Isolation Levels

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    CURRENT ACTIVE BLOCKING OVERVIEW
-------------------------------------------------------------------------------
.PURPOSE
    Identify all currently executing requests that are blocked.

.HEALTHY
    No rows returned.

.WARNING
    Multiple rows returned with high wait_time.
-----------------------------------------------------------------------------*/

SELECT
    r.session_id AS BlockedSessionId,
    r.blocking_session_id AS BlockerSessionId,
    r.wait_type AS WaitType,
    r.wait_time / 1000.0 AS WaitTimeSeconds,
    r.status AS RequestStatus,
    r.command AS CommandType,
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
    SECTION 2
    BLOCKING TREE & CHAIN HIERARCHY
-------------------------------------------------------------------------------
.PURPOSE
    Visualize the parent-child relationship in blocking chains.
-----------------------------------------------------------------------------*/

WITH BlockingHierarchy AS
(
    SELECT
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        0 AS [Level]
    FROM sys.dm_exec_requests r
    WHERE r.blocking_session_id <> 0
      AND r.blocking_session_id NOT IN (SELECT session_id FROM sys.dm_exec_requests WHERE blocking_session_id <> 0)
    
    UNION ALL
    
    SELECT
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        b.[Level] + 1
    FROM sys.dm_exec_requests r
    INNER JOIN BlockingHierarchy b
        ON r.blocking_session_id = b.session_id
)
SELECT
    REPLICATE('--> ', [Level]) + CAST(session_id AS VARCHAR(10)) AS BlockingTree,
    session_id AS BlockedSessionId,
    blocking_session_id AS BlockerSessionId,
    wait_type,
    wait_time / 1000.0 AS WaitTimeSeconds,
    [Level]
FROM BlockingHierarchy
ORDER BY [Level], wait_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    HEAD BLOCKERS (INCLUDING SLEEPING / IDLE SESSIONS)
-------------------------------------------------------------------------------
.PURPOSE
    Identify the root cause sessions responsible for blocking other processes.

.CRITICAL NOTE
    Often the head blocker is an IDLE/SLEEPING session that left a transaction open
    without committing or rolling back. This query captures active AND sleeping blockers.
-----------------------------------------------------------------------------*/

WITH Blockers AS
(
    SELECT DISTINCT blocking_session_id AS HeadBlockerSessionId
    FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
      AND blocking_session_id NOT IN
      (
          SELECT session_id
          FROM sys.dm_exec_requests
          WHERE blocking_session_id <> 0
      )
)
SELECT
    b.HeadBlockerSessionId,
    s.status AS SessionStatus,
    s.login_name AS LoginName,
    s.host_name AS HostName,
    s.program_name AS ProgramName,
    s.last_request_start_time AS LastRequestStartTime,
    s.last_request_end_time AS LastRequestEndTime,
    r.command AS ActiveCommand,
    r.cpu_time AS ActiveCPUTimeMs,
    r.total_elapsed_time AS ActiveElapsedTimeMs,
    ib.event_info AS [LastInputBuffer / Statement],
    (
        SELECT COUNT(*)
        FROM sys.dm_tran_session_transactions tst
        WHERE tst.session_id = b.HeadBlockerSessionId
    ) AS OpenTransactionsCount
FROM Blockers b
INNER JOIN sys.dm_exec_sessions s
    ON b.HeadBlockerSessionId = s.session_id
LEFT JOIN sys.dm_exec_requests r
    ON b.HeadBlockerSessionId = r.session_id
OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) ib;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    BLOCKED REQUEST DETAILS
-------------------------------------------------------------------------------
.PURPOSE
    Show statement-level text and database context for blocked queries.
-----------------------------------------------------------------------------*/

SELECT
    r.session_id AS BlockedSessionId,
    r.blocking_session_id AS BlockerSessionId,
    r.wait_time / 1000.0 AS WaitSeconds,
    r.wait_type,
    r.wait_resource,
    DB_NAME(r.database_id) AS DatabaseName,
    s.login_name,
    s.host_name,
    s.program_name,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS BlockedStatementText
FROM sys.dm_exec_requests r
INNER JOIN sys.dm_exec_sessions s
    ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    EXECUTION PLANS FOR ACTIVE BLOCKING SESSIONS
-------------------------------------------------------------------------------
.PURPOSE
    Retrieve execution plans for active blockers to detect large scans or locks.
-----------------------------------------------------------------------------*/

SELECT
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
WHERE r.session_id IN
(
    SELECT DISTINCT blocking_session_id
    FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
)
OPTION (MAXDOP 1);
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    WAITING LOCKS & CONTENTION
-------------------------------------------------------------------------------
.PURPOSE
    Show active lock requests that are currently in a WAITING state.

.SAFETY NOTE
    Filtered strictly to request_status = 'WAIT' to prevent dumping millions
    of granted row/key locks on busy systems.
-----------------------------------------------------------------------------*/

SELECT
    tl.request_session_id AS WaitingSessionId,
    tl.resource_type AS ResourceType,
    DB_NAME(tl.resource_database_id) AS DatabaseName,
    tl.resource_description AS ResourceDescription,
    tl.request_mode AS RequestedLockMode,
    tl.request_status AS LockStatus
FROM sys.dm_tran_locks tl
WHERE tl.request_status = 'WAIT'
ORDER BY tl.request_session_id;
GO

/*-----------------------------------------------------------------------------
    SECTION 7
    LOCK WAIT STATISTICS (LCK_M_*)
-------------------------------------------------------------------------------
.PURPOSE
    Review cumulative wait time spent acquiring locks.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms / 1000.0 AS TotalWaitSeconds,
    max_wait_time_ms / 1000.0 AS MaxWaitSeconds,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'LCK_M_%'
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    ACTIVE OPEN TRANSACTIONS ACROSS INSTANCE
-------------------------------------------------------------------------------
.PURPOSE
    Identify all open transactions across all databases.
-----------------------------------------------------------------------------*/

SELECT
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    s.status AS SessionStatus,
    tat.transaction_id,
    tat.transaction_begin_time,
    DATEDIFF(MINUTE, tat.transaction_begin_time, GETDATE()) AS MinutesOpen,
    tat.transaction_type AS TransactionType,
    tat.transaction_state AS TransactionState
FROM sys.dm_tran_active_transactions tat
INNER JOIN sys.dm_tran_session_transactions tst
    ON tat.transaction_id = tst.transaction_id
INNER JOIN sys.dm_exec_sessions s
    ON tst.session_id = s.session_id
WHERE s.is_user_process = 1
ORDER BY tat.transaction_begin_time ASC;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    LONG-RUNNING ACTIVE TRANSACTIONS
-------------------------------------------------------------------------------
.PURPOSE
    Identify transactions open for more than 5 minutes.
-----------------------------------------------------------------------------*/

SELECT
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    tat.transaction_id,
    tat.transaction_begin_time,
    DATEDIFF(MINUTE, tat.transaction_begin_time, GETDATE()) AS MinutesOpen,
    ib.event_info AS [LastKnownStatement]
FROM sys.dm_tran_active_transactions tat
INNER JOIN sys.dm_tran_session_transactions tst
    ON tat.transaction_id = tst.transaction_id
INNER JOIN sys.dm_exec_sessions s
    ON tst.session_id = s.session_id
OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) ib
WHERE DATEDIFF(MINUTE, tat.transaction_begin_time, GETDATE()) >= 5
ORDER BY tat.transaction_begin_time ASC;
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    LOCK SUMMARY BY RESOURCE TYPE & MODE (ESCALATION CHECK)
-------------------------------------------------------------------------------
.PURPOSE
    Aggregate locks by resource type to identify table/object level lock escalation.
-----------------------------------------------------------------------------*/

SELECT
    resource_type,
    request_mode,
    request_status,
    COUNT(*) AS LockCount
FROM sys.dm_tran_locks
GROUP BY
    resource_type,
    request_mode,
    request_status
ORDER BY LockCount DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 11
    DEADLOCK ACTIVITY & RATE OVERVIEW
-------------------------------------------------------------------------------
.PURPOSE
    Inspect cumulative deadlock counts since instance startup.
-----------------------------------------------------------------------------*/

SELECT
    counter_name,
    cntr_value AS CumulativeDeadlocksSinceStartup
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Number of Deadlocks/sec';
GO

/*-----------------------------------------------------------------------------
    SECTION 12
    USER SESSION ISOLATION LEVEL DISTRIBUTION
-------------------------------------------------------------------------------
.PURPOSE
    Review active user session transaction isolation levels.
-----------------------------------------------------------------------------*/

SELECT
    CASE transaction_isolation_level
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'ReadUncommitted'
        WHEN 2 THEN 'ReadCommitted'
        WHEN 3 THEN 'RepeatableRead'
        WHEN 4 THEN 'Serializable'
        WHEN 5 THEN 'Snapshot'
        ELSE 'Unknown'
    END AS IsolationLevelDesc,
    COUNT(*) AS ActiveSessionCount
FROM sys.dm_exec_sessions
WHERE is_user_process = 1
GROUP BY transaction_isolation_level
ORDER BY ActiveSessionCount DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 13
    DATABASE SNAPSHOT / RCSI CONFIGURATION
-------------------------------------------------------------------------------
.PURPOSE
    Review Read Committed Snapshot Isolation (RCSI) and Snapshot Isolation settings.
-----------------------------------------------------------------------------*/

SELECT
    name AS DatabaseName,
    is_read_committed_snapshot_on AS IsRCSIOn,
    snapshot_isolation_state_desc AS SnapshotIsolationState
FROM sys.databases
WHERE database_id > 4;
GO

/*-----------------------------------------------------------------------------
    SECTION 14
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    High-level concurrency summary dashboard.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id <> 0) AS BlockedRequests,
    (SELECT COUNT(DISTINCT blocking_session_id) FROM sys.dm_exec_requests WHERE blocking_session_id <> 0) AS ActiveBlockerCount,
    (SELECT COUNT(*) FROM sys.dm_tran_active_transactions) AS TotalActiveTransactions,
    (SELECT COUNT(*) FROM sys.dm_tran_locks WHERE request_status = 'WAIT') AS TotalWaitingLocks;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
CONCURRENCY SYMPTOM                 ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
Active Blocker is Sleeping (Idle)   --> Identify client app holding open transaction (Section 3)
High LCK_M_X on Table/Object        --> Lock escalation occurring; review batch sizes & indexes
Frequent Deadlocks                  --> Review query access order & enable Deadlock Extended Event
High Read/Write Lock Contention     --> Evaluate Read Committed Snapshot Isolation (RCSI)
******************************************************************************/
