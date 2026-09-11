-- percentage completed
SELECT session_id
	  ,name
	  ,[status]
	  ,start_time
	  ,convert(varchar,(total_elapsed_time/(1000))/60) + 'M ' + convert(varchar,(total_elapsed_time/(1000))%60) + 'S' AS [Elapsed]
	  ,convert(varchar,(estimated_completion_time/(1000))/60) + 'M ' + convert(varchar,(estimated_completion_time/(1000))%60) + 'S' as [ETA]
	  ,command
	  --,[sql_handle]
	  ,d.name as db_name
	  --,connection_id
	  ,blocking_session_id
	  ,percent_complete
FROM sys.dm_exec_requests er
INNER JOIN sys.databases d ON d.database_id = er.database_id
WHERE estimated_completion_time > 1
ORDER BY total_elapsed_time DESC