SELECT s.session_id
	  ,DB_NAME(database_id) AS database_name
	  ,s.login_name
	  ,s.host_name
	  ,s.program_name
	  ,s.status
	  ,REPLACE(TEXT, CHAR(13) + CHAR(10), '') AS sql_query
FROM sys.dm_exec_sessions s
INNER JOIN sys.dm_exec_connections c ON c.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(most_recent_sql_handle)
WHERE login_name != SYSTEM_USER  
AND DB_NAME(database_id) IN ('CMORD')
--CMORD, CMATL, CMLAX, CMMIA, MGMSUSGlobalDB
ORDER BY database_id
