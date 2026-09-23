with blocker as (
SELECT distinct blocking_session_id
FROM sys.dm_exec_requests
)
select sqltext.text, query_plan, er.* from sys.dm_exec_requests er
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext
CROSS APPLY sys.dm_exec_query_plan(plan_handle)
where session_id in (select * from blocker)