-- Identificar consultas que están solicitando y utilizando memoria de ejecución (grants)
SELECT
    mg.granted_memory_kb, 
    mg.session_id, 
    t.text, 
    qp.query_plan
FROM sys.dm_exec_query_memory_grants AS mg
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) AS t
CROSS APPLY sys.dm_exec_query_plan(mg.plan_handle) AS qp
ORDER BY 1 DESC 
OPTION (MAXDOP 1)

-- Ver memoria total usada por SQL Server
SELECT physical_memory_in_use_kb / 1024 AS SQLServerMemoryMB
      ,locked_page_allocations_kb / 1024 AS LockedPagesMB
      ,page_fault_count
      ,memory_utilization_percentage
      ,available_commit_limit_kb / 1024 AS CommitLimitMB
      --,committed_kb / 1024 AS CommittedMB
FROM sys.dm_os_process_memory;

-- Ver uso de memoria por tipo
SELECT 
    type, 
    SUM(pages_kb) / 1024 AS MemoryMB
FROM sys.dm_os_memory_clerks
GROUP BY type
ORDER BY MemoryMB DESC;

-- Consultas que más consumen recursos
SELECT TOP 10
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_time,
    qs.execution_count,
    qs.total_logical_writes / qs.execution_count AS avg_logical_writes,
	qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    qs.total_worker_time / qs.execution_count AS avg_cpu_time,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset END
            - qs.statement_start_offset)/2)+1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY avg_logical_reads DESC;

--Memory Grants Pending
SELECT COUNT(*) AS MemoryGrantsPending
FROM sys.dm_exec_query_memory_grants
WHERE grant_time IS NULL;

-- PLE
SELECT
    [object_name], 
    [counter_name], 
    [cntr_value] AS PageLifeExpectancy
FROM sys.dm_os_performance_counters
WHERE [counter_name] = 'Page life expectancy';
