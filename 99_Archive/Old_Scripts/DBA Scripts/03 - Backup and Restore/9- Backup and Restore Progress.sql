--**--**--**--**--Database Restore Progress--**--**--**--**--

SELECT session_id as spid
	  ,command
	  ,a.text AS query
	  ,start_time, percent_complete
	  ,dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time 
FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a 
WHERE r.command in ('BACKUP DATABASE','RESTORE DATABASE') 