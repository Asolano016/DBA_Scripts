/******************************************************************************
SQL SERVER ACTIVE HIGH CPU SESSIONS SNAPSHOT
-------------------------------------------------------------------------------
PURPOSE
    Quick standalone diagnostic query to capture currently running requests
    ordered by CPU consumption (cpu_time DESC).

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)
******************************************************************************/

SELECT
    s.session_id,
    r.status,
    r.blocking_session_id AS BlockedBySessionId,
    r.wait_type AS WaitType,
    r.wait_resource AS WaitResource,
    r.wait_time / 1000.0 AS WaitTimeSeconds,
    r.cpu_time AS CPUTimeMs,
    r.logical_reads AS LogicalReads,
    r.reads AS PhysicalReads,
    r.writes AS Writes,
    r.total_elapsed_time / 1000.0 AS ElapsedTimeSeconds,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS StatementText,
    COALESCE(
        QUOTENAME(DB_NAME(st.dbid)) + N'.' +
        QUOTENAME(OBJECT_SCHEMA_NAME(st.objectid, st.dbid)) + N'.' +
        QUOTENAME(OBJECT_NAME(st.objectid, st.dbid)),
        N''
    ) AS ObjectFullName,
    r.command AS CommandType,
    s.login_name AS LoginName,
    s.host_name AS HostName,
    s.program_name AS ProgramName,
    s.last_request_end_time AS LastRequestEndTime,
    s.login_time AS LoginTime,
    r.open_transaction_count AS OpenTransactionCount
FROM sys.dm_exec_sessions AS s
INNER JOIN sys.dm_exec_requests AS r
    ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
WHERE r.session_id <> @@SPID
  AND s.is_user_process = 1
ORDER BY r.cpu_time DESC;
GO
