-- sessions running
SELECT   RunTime = getdate(),SPID       = er.session_id
    ,STATUS         = ses.STATUS
    ,[Login]        = ses.login_name
    ,Host           = ses.host_name
    ,BlkBy          = er.blocking_session_id
    ,DBName         = DB_Name(er.database_id)
    ,CommandType    = er.command
    ,ObjectName     = OBJECT_NAME(st.objectid)
    ,CPUTime        = er.cpu_time
    ,StartTime      = er.start_time
    ,TimeElapsed    = CAST(GETDATE() - er.start_time AS TIME)
    ,SQLStatement   = st.text
FROM    sys.dm_exec_requests er
    OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) st
    LEFT JOIN sys.dm_exec_sessions ses
    ON ses.session_id = er.session_id
LEFT JOIN sys.dm_exec_connections con
    ON con.session_id = ses.session_id
WHERE   st.text IS NOT NULL
And con.session_Id NOT IN (@@SPID)



-- threads sessions running

SELECT
er.session_Id AS [Spid]
, sp.ecid,BlkBy          = er.blocking_session_id
, er.start_time
, DATEDIFF(SS,er.start_time,GETDATE()) as [Age Seconds]
, sp.nt_username
,   DBName         = DB_Name(er.database_id)
, er.status
, er.wait_type
, SUBSTRING (qt.text, (er.statement_start_offset/2) + 1,
((CASE WHEN er.statement_end_offset = -1
THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
ELSE er.statement_end_offset
END - er.statement_start_offset)/2) + 1) AS [Individual Query]
, qt.text AS [Parent Query]
, sp.program_name
, sp.Hostname
, sp.nt_domain
FROM sys.dm_exec_requests er
INNER JOIN sys.sysprocesses sp ON er.session_id = sp.spid
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle)as qt
WHERE session_Id > 50
AND session_Id NOT IN (@@SPID)
ORDER BY session_Id, ecid


-- percentage completed
select 
session_id,
name,
[status],
start_time,
convert(varchar,(total_elapsed_time/(1000))/60) + 'M ' + convert(varchar,(total_elapsed_time/(1000))%60) + 'S' AS [Elapsed],
convert(varchar,(estimated_completion_time/(1000))/60) + 'M ' + convert(varchar,(estimated_completion_time/(1000))%60) + 'S' as [ETA],
command,
-- [sql_handle],
d.name as db_name,
-- connection_id,
blocking_session_id,
percent_complete
from  sys.dm_exec_requests er
inner join sys.databases d on d.database_id = er.database_id
where estimated_completion_time > 1
order by total_elapsed_time desc




