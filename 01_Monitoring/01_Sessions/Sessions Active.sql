-- threads sessions running
SELECT er.session_Id AS [Spid]
	  ,sp.ecid,BlkBy          = er.blocking_session_id
	  ,er.start_time
	  ,DATEDIFF(SS,er.start_time,GETDATE()) as [Age Seconds]
	  ,sp.nt_username
	  ,DBName = DB_Name(er.database_id)
	  ,er.status
	  ,er.wait_type
	  ,SUBSTRING (qt.text, (er.statement_start_offset/2) + 1, ((CASE WHEN er.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 ELSE er.statement_end_offset END - er.statement_start_offset)/2) + 1) AS [Individual Query]
	  ,qt.text AS [Parent Query]
	  ,sp.program_name
	  ,sp.Hostname
	  ,sp.nt_domain
FROM sys.dm_exec_requests er
INNER JOIN sys.sysprocesses sp ON er.session_id = sp.spid
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle)as qt
WHERE session_Id > 50
AND session_Id NOT IN (@@SPID)
ORDER BY session_Id, ecid