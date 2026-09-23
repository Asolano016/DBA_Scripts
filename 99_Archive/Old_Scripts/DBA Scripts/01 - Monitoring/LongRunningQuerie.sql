SELECT  st.text,
        --qp.query_plan,
        qs.*
FROM    (
    SELECT  TOP 20 *
    FROM    sys.dm_exec_query_stats
	--WHERE creation_time BETWEEN '2021-06-15 05:00' AND '2021-06-15 19:00'
    ORDER BY total_worker_time DESC
) AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE qs.max_worker_time > 300
      OR qs.max_elapsed_time > 300