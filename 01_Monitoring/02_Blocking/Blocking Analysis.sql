/*Script - Check Blocking Transaction*/
SELECT  db_name(dtl.resource_database_id) AS 'Database'
       ,dtl.resource_type AS 'ResourceType'
       ,CASE 
			WHEN dtl.resource_type IN ( 'DATABASE', 'FILE', 'METADATA' ) THEN dtl.resource_type
            WHEN dtl.resource_type = 'OBJECT' THEN OBJECT_NAME(dtl.resource_associated_entity_id)
            WHEN dtl.resource_type IN ( 'KEY', 'PAGE', 'RID' ) THEN (SELECT  OBJECT_NAME(object_id) FROM sys.partitions WHERE sys.partitions.hobt_id = dtl.resource_associated_entity_id)
             ELSE 'Unidentified'
        END AS 'ParentObject'
       ,dtl.request_mode AS 'LockType'
       ,dtl.request_status AS 'RequestStatus'
       ,dowt.wait_duration_ms AS 'WaitDuration(ms)'
       ,dowt.wait_type AS 'WaitType'
       ,dowt.session_id AS 'BlockedSessionID'
       ,des_blocked.login_name AS 'BlockedLogin'
       ,SUBSTRING(dest_blocked.text, (der.statement_start_offset / 2) + 1, ( CASE WHEN der.statement_end_offset = -1 THEN DATALENGTH(dest_blocked.text) ELSE der.statement_end_offset END - der.statement_start_offset) / 2) AS 'BlockedCommand'
       ,dowt.blocking_session_id AS 'BlockingSessionID'
       ,des_blocking.login_name AS 'BlockingLogin'
       ,dest_blocking.text AS 'BlockingCommand'
       ,dowt.resource_description AS 'BlockingResourceDetail'
FROM sys.dm_tran_locks dtl
INNER JOIN sys.dm_os_waiting_tasks dowt ON dtl.lock_owner_address = dowt.resource_address
INNER JOIN sys.dm_exec_requests der ON dowt.session_id = der.session_id
INNER JOIN sys.dm_exec_sessions des_blocked ON dowt.session_id = des_blocked.session_id
INNER JOIN sys.dm_exec_sessions des_blocking ON dowt.blocking_session_id = des_blocking.session_id
INNER JOIN sys.dm_exec_connections dec ON dowt.blocking_session_id = dec.most_recent_session_id
CROSS APPLY sys.dm_exec_sql_text(dec.most_recent_sql_handle) AS dest_blocking
CROSS APPLY sys.dm_exec_sql_text(der.sql_handle) AS dest_blocked
ORder BY dowt.blocking_session_id 