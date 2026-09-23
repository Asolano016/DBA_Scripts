-- query vs cpu time

select top 10 	st.objectid, st.dbid,	
object_name(st.objectid, st.dbid) as ObjectName, total_worker_time, execution_count,
total_worker_time/execution_count AS AverageCPUTime,	
CASE statement_end_offset WHEN -1 THEN st.text		
ELSE SUBSTRING(st.text,statement_start_offset/2,statement_end_offset/2)	
END AS StatementText, QP.QUERY_PLAN, creation_time, last_execution_time, 
last_worker_time, min_worker_time, max_worker_time
from sys.dm_exec_query_stats qs 
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_query_plan(QS.plan_handle) QP
--Where st.dbid = 37
ORDER BY averagecputime DESC


/* THIS SECTION FOR KEY: WAITRESOURCE */


SELECT o.name, i.name 
FROM sys.partitions p 
JOIN sys.objects o ON p.object_id = o.object_id 
JOIN sys.indexes i ON p.object_id = i.object_id 
AND p.index_id = i.index_id 
WHERE p.hobt_id = 72057597089284096 


/* Translating Page Waits */
declare @db sysname;
set @db = DB_NAME(5)
dbcc page (@db , 1, 5849012, 0) with tableresults,no_infomsgs
 

select object_name(1728165352)


/* THIS SECTION FOR SQL EXECUTION REQUESTS */

select  r.database_id,
	r.status,
        r.command,
        r.wait_resource,
        r.wait_type,
        r.wait_time,
        qp.query_plan,
        [statement_text]=SUBSTRING(st.text, (r.statement_start_offset/2)+1,
                        ((CASE r.statement_end_offset
                            WHEN -1 THEN DATALENGTH(st.text)
                                ELSE r.statement_end_offset
                            END - r.statement_start_offset)/2) + 1),
        st.text
from sys.dm_exec_requests r
    outer apply sys.dm_exec_sql_text (r.sql_handle) st
    cross apply sys.dm_exec_query_plan(r.plan_handle) qp
    --where r.database_id = 15
    
    
/* INDEX FRAG SPECIFIC TABLE */

select c.name as Table_Name, b.name as Index_Name,a.avg_fragmentation_in_percent 
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('hostplus_incoming'), NULL, NULL, NULL) as a
join sysindexes b on a.object_id = b.id and a.index_id =b.indid
join sysobjects c on a.object_id = c.id
ORDER BY 1,2

/* INDEX FRAG ALL TABLES AND INDEXES */

select c.name as Table_Name, b.name as Index_Name,a.avg_fragmentation_in_percent 
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) as a
join sysindexes b on a.object_id = b.id and a.index_id =b.indid
join sysobjects c on a.object_id = c.id
ORDER BY 1,2

/* Record count and Page Count */
select c.name as Table_Name, b.name as Index_Name, a.record_count, a.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') as a
join sysindexes b on a.object_id = b.id and a.index_id =b.indid
join sysobjects c on a.object_id = c.id
ORDER BY 1,2


SELECT st.text AS [SQL Text],
w.session_id, 
w.wait_duration_ms,
w.wait_type, w.resource_address, 
w.blocking_session_id, 
w.resource_description FROM sys.dm_os_waiting_tasks AS w
INNER JOIN sys.dm_exec_connections AS c ON w.session_id = c.session_id 
CROSS APPLY (SELECT * FROM sys.dm_exec_sql_text(c.most_recent_sql_handle))
AS st WHERE w.session_id > 50
AND w.wait_duration_ms > 0


-- THIS QUERY WILL LIST TOP WAITS

WITH Waits AS 
 ( 
 SELECT  
   wait_type,  
   wait_time_ms / 1000. AS wait_time_sec, 
   100. * wait_time_ms / SUM(wait_time_ms) OVER() AS pct, 
   ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn 
 FROM sys.dm_os_wait_stats 
 WHERE wait_type  
   NOT IN 
     ('CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 
   'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 
   'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT') 
   ) -- filter out additional irrelevant waits 
    
SELECT W1.wait_type, 
 CAST(W1.wait_time_sec AS DECIMAL(12, 2)) AS wait_time_sec, 
 CAST(W1.pct AS DECIMAL(12, 2)) AS pct, 
 CAST(SUM(W2.pct) AS DECIMAL(12, 2)) AS running_pct 
FROM Waits AS W1 
 INNER JOIN Waits AS W2 ON W2.rn <= W1.rn 
GROUP BY W1.rn,  
 W1.wait_type,  
 W1.wait_time_sec,  
 W1.pct 
HAVING SUM(W2.pct) - W1.pct < 98; -- percentage threshold; 

 
 
select top 10 * 
from sys.dm_exec_query_stats 
cross apply sys.dm_exec_sql_text(sql_handle)
cross apply sys.dm_exec_query_plan(plan_handle)
order by last_elapsed_time desc


-- SCHEDULER STATUS

SELECT scheduler_id, cpu_id, CASE is_idle WHEN 1 THEN 'YES' ELSE 'NO' END AS IDLE,current_tasks_count, runnable_tasks_count,
current_workers_count, active_workers_count, work_queue_count, load_factor 
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255 


select * from sys.dm_os_memory_nodes
 
    
-- TEMPDB USAGE QUERIES

SELECT session_id AS SessionID,
wait_duration_ms AS Wait_Time_In_Milliseconds,
resource_description AS Type_of_Allocation_Contention
FROM sys.dm_os_waiting_tasks
WHERE wait_type LIKE 'PAGELATCH_%'
AND (resource_description LIKE '2:%:1'
OR resource_description LIKE '2:%:2'
OR resource_description LIKE '2:%:3')

/*
Allocation Page Contention:
2:1:1 = PFS Page
2:1:2 = GAM Page
2:1:3: = SGAM Page
*/


SELECT 
    name AS FileName, 
    size*1.0/128 AS FileSizeinMB,
    CASE max_size 
        WHEN 0 THEN 'Autogrowth is off.'
        WHEN -1 THEN 'Autogrowth is on.'
        ELSE 'Log file will grow to a maximum size of 2 TB.'
    END,
    growth AS 'GrowthValue',
    'GrowthIncrement' = 
        CASE
            WHEN growth = 0 THEN 'Size is fixed and will not grow.'
            WHEN growth > 0 AND is_percent_growth = 0 
                THEN 'Growth value is in 8-KB pages.'
            ELSE 'Growth value is a percentage.'
        END
FROM tempdb.sys.database_files;
GO



SELECT
SUM (user_object_reserved_page_count)*8 as usr_obj_kb,
SUM (internal_object_reserved_page_count)*8 as
internal_obj_kb,
SUM (version_store_reserved_page_count)*8 as
version_store_kb
FROM sys.dm_db_file_space_usage   


SELECT SPID, CPU, s2.text, open_tran, status, program_name, net_library, loginame
FROM sys.sysprocesses 
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS s2
WHERE CPU > 5000           -- CPU usage greater than 5 seconds
and status = 'runnable' -- Active sessions
 
-- CPU INTENSIVE QUERIES
 
Select Top 10 DB_NAME(st.dbid) AS Database_Name, last_execution_time, (total_worker_time) As [Total CPU time],  
execution_count, (total_worker_time/execution_count) As [Avg CPU time], creation_time, max_worker_time,
min_worker_time,last_worker_time,
text, qp.query_plan 
From sys.dm_exec_query_stats As qs
Cross apply sys.dm_exec_sql_text(qs.sql_handle) As st
Cross apply sys.dm_exec_query_plan(qs.plan_handle) as qp
Where DateDiff(hour, last_execution_time, getdate()) < 1 
Order by total_worker_time DESC;

-- SAME QUERY AS ABOVE WITHOUT EXPLAIN PLAN

Select Top 10 DB_NAME(st.dbid) AS Database_Name, last_execution_time, (total_worker_time/1000000) As [Total CPU time SEC],  
execution_count, cast((total_worker_time/execution_count)as decimal(20))/1000000 As [Avg CPU time SEC], 
creation_time, cast(max_worker_time as decimal(20))/1000000 as max_worker_time_SEC,
cast(min_worker_time as decimal(20))/1000000 as min_worker_time_SEC,
cast(last_worker_time as decimal(20))/1000000 as last_worker_time_SEC,
text
From sys.dm_exec_query_stats As qs
Cross apply sys.dm_exec_sql_text(qs.sql_handle) As st
Where DateDiff(hour, last_execution_time, getdate()) < 1
Order by total_worker_time DESC;
 
 
-- BLOCKING SCRIPT 
 
SELECT t1.resource_type AS [lock type],DB_NAME(resource_database_id) AS [database],
t1.resource_associated_entity_id AS [blk object],t1.request_mode AS [lock req], --- lock requested
t1.request_session_id AS [waiter sid], t2.wait_duration_ms AS [wait time], -- spid of waiter  
(SELECT [text] FROM sys.dm_exec_requests AS r                              -- get sql for waiter
CROSS APPLY sys.dm_exec_sql_text(r.[sql_handle]) 
WHERE r.session_id = t1.request_session_id) AS [waiter_batch],
(SELECT SUBSTRING(qt.[text],r.statement_start_offset/2, 
    (CASE WHEN r.statement_end_offset = -1 
    THEN LEN(CONVERT(nvarchar(max), qt.[text])) * 2 
    ELSE r.statement_end_offset END - r.statement_start_offset)/2) 
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.[sql_handle]) AS qt
WHERE r.session_id = t1.request_session_id) AS [waiter_stmt],    -- statement blocked
t2.blocking_session_id AS [blocker sid],                         -- spid of blocker
(SELECT [text] FROM sys.sysprocesses AS p                        -- get sql for blocker
CROSS APPLY sys.dm_exec_sql_text(p.[sql_handle]) 
WHERE p.spid = t2.blocking_session_id) AS [blocker_stmt]
FROM sys.dm_tran_locks AS t1 
INNER JOIN sys.dm_os_waiting_tasks AS t2
ON t1.lock_owner_address = t2.resource_address; 

-- WORKERS WAITING FOR CPU

SELECT COUNT(*) AS workers_waiting_for_cpu, t2.Scheduler_id
FROM sys.dm_os_workers AS t1, sys.dm_os_schedulers AS t2
WHERE t1.state = 'RUNNABLE' AND
   t1.scheduler_address = t2.scheduler_address AND
   t2.scheduler_id < 255
GROUP BY t2.scheduler_id


-- OS AND CUP INFO

SELECT * FROM sys.dm_os_sys_info

SELECT cpu_count, hyperthread_ratio, scheduler_count, socket_count, cores_per_socket, numa_node_count
FROM sys.dm_os_sys_info

-- SIGNAL WAITS VS RESOURCE WAITS

Select signal_wait_time_ms=sum(signal_wait_time_ms)
          ,'%signal (cpu) waits' = cast(100.0 *
sum(signal_wait_time_ms) / sum (wait_time_ms) as numeric(20,2))
          ,resource_wait_time_ms=sum(wait_time_ms - signal_wait_time_ms)
          ,'%resource waits'= cast(100.0 * sum(wait_time_ms -
signal_wait_time_ms) / sum (wait_time_ms) as numeric(20,2))
From sys.dm_os_wait_stats
 
-- CPU

SELECT es.session_id
    ,es.program_name
    ,es.login_name
    ,es.nt_user_name
    ,es.login_time
    ,es.host_name
    ,es.cpu_time
    ,es.total_scheduled_time
    ,es.total_elapsed_time
    ,es.memory_usage
    ,es.logical_reads
    ,es.reads
    ,es.writes
    ,st.text
FROM sys.dm_exec_sessions es
    LEFT JOIN sys.dm_exec_connections ec 
        ON es.session_id = ec.session_id
    LEFT JOIN sys.dm_exec_requests er
        ON es.session_id = er.session_id
    OUTER APPLY sys.dm_exec_sql_text (er.sql_handle) st
WHERE es.session_id > 50    
ORDER BY es.cpu_time DESC

-- RECOMPILE

SELECT TOP 10 plan_generation_num, execution_count,
   (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
      (CASE WHEN statement_end_offset = -1
         THEN LEN(CONVERT(nvarchar(max),text)) * 2
         ELSE statement_end_offset
      END - statement_start_offset)/2)
   FROM sys.dm_exec_sql_text(sql_handle)) AS query_text
FROM sys.dm_exec_query_stats
WHERE plan_generation_num >1
ORDER BY plan_generation_num DESC

-- AD HOC DYNAMIC QUERIES

select q.query_hash, 
      q.number_of_entries, 
      t.text as sample_query, 
      p.query_plan as sample_plan
from (select top 20 query_hash, 
                  count(*) as number_of_entries, 
                  min(sql_handle) as sample_sql_handle, 
                  min(plan_handle) as sample_plan_handle
            from sys.dm_exec_query_stats
            group by query_hash
            having count(*) > 1
            order by count(*) desc) as q
      cross apply sys.dm_exec_sql_text(q.sample_sql_handle) as t
      cross apply sys.dm_exec_query_plan(q.sample_plan_handle) as p
go

-- AD HOC DYNAMIC QUERIES 2


select q.query_hash, 
q.number_of_entries, 
q.distinct_plans,
t.text as sample_query, 
p.query_plan as sample_plan
from (select top 20 query_hash, 
count(*) as number_of_entries, 
count(distinct query_plan_hash) as distinct_plans,
min(sql_handle) as sample_sql_handle, 
min(plan_handle) as sample_plan_handle
from sys.dm_exec_query_stats
group by query_hash
having count(*) > 1
order by count(*) desc) as q
cross apply sys.dm_exec_sql_text(q.sample_sql_handle) as t
cross apply sys.dm_exec_query_plan(q.sample_plan_handle) as p
go


-- OPTIMIZER TIME INFO

select * from sys.dm_exec_query_optimizer_info

-- CXPACKET QUERIES

select 
    r.session_id,
    r.request_id,
    max(isnull(exec_context_id, 0)) as number_of_workers,
    r.sql_handle,
    r.statement_start_offset,
    r.statement_end_offset,
    r.plan_handle
from sys.dm_exec_requests r
    join sys.dm_os_tasks t on r.session_id = t.session_id
    join sys.dm_exec_sessions s on r.session_id = s.session_id
where s.is_user_process = 0x1
group by r.session_id, r.request_id, 
    r.sql_handle, r.plan_handle, 
    r.statement_start_offset, r.statement_end_offset
having max(isnull(exec_context_id, 0)) > 0

-- CHECK FOR CURSORS
 
select cur.* 
from sys.dm_exec_connections con
    cross apply sys.dm_exec_cursors(con.session_id) as cur
where cur.fetch_buffer_size = 1 
    and cur.properties LIKE 'API%'  -- API cursor (Transact-SQL cursors 


-- OPTIMUM MAXDOP SETTING

select 
    case 
        when cpu_count / hyperthread_ratio > 8 then 8
        else cpu_count / hyperthread_ratio
    end as optimal_maxdop_setting
from sys.dm_os_sys_info


--find the name of the table and clustered index that goes with partition_id 422219771609088 by running the statement below:

select schema_name(o.schema_id) as SchemaName, o.name as ObjectName, i.name as IndexName
from sys.partitions p
inner join sys.indexes i on p.object_id = i.object_id
inner join sys.objects o on p.object_id = o.object_id
where p.partition_id = 422219771609088 and i.index_id = 1;




 
