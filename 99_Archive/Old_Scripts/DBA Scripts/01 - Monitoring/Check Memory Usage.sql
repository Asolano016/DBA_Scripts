SELECT session_id, granted_memory_kb, requested_memory_kb, plan_handle, sql_handle 
FROM sys.dm_exec_query_memory_grants
order by granted_memory_kb desc, requested_memory_kb desc; 