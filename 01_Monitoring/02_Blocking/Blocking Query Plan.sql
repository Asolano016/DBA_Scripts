WITH blocker AS (
	SELECT distinct blocking_session_id
	FROM sys.dm_exec_requests
)
SELECT sqltext.text
	  ,query_plan
	  ,er.* 
FROM sys.dm_exec_requests er
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext
CROSS APPLY sys.dm_exec_query_plan(plan_handle)
WHERE session_id in (SELECT * FROM blocker)