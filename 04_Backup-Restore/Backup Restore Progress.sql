/******************************************************************************
BACKUP / RESTORE PROGRESS
-------------------------------------------------------------------------------

PURPOSE

    Monitor active BACKUP and RESTORE operations.

OUTPUT

    • Session ID
    • Operation Type
    • Progress %
    • Elapsed Time
    • Estimated Completion Time
    • Estimated Remaining Time
    • SQL Command

******************************************************************************/

SELECT r.session_id AS SessionID
      ,DB_NAME(r.database_id) AS DatabaseName
      ,r.command AS Command
      ,t.text AS CommandText
      ,CAST(r.percent_complete AS DECIMAL(6,2)) AS PercentComplete
      ,CAST(r.total_elapsed_time / 1000.0 / 60.0 AS DECIMAL(10,2)) AS ElapsedMinutes
      ,CAST(r.estimated_completion_time / 1000.0 / 60.0 AS DECIMAL(10,2)) AS RemainingMinutes
      ,CONVERT(VARCHAR(19), DATEADD(MILLISECOND, r.estimated_completion_time, GETDATE()), 120) AS EstimatedCompletionTime
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.command IN ('BACKUP DATABASE', 'BACKUP LOG', 'RESTORE DATABASE', 'RESTORE LOG')
ORDER BY r.percent_complete DESC;