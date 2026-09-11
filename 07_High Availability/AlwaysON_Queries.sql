-- Scripts for AlwaysON monitoring

SELECT sys.fn_hadr_is_primary_replica ('DBNAME');  
--Shows 1 for Primary, 0 for Secondary


-- List AG Replica Details 
select n.group_name,n.replica_server_name,n.node_name,rs.role_desc 
from sys.dm_hadr_availability_replica_cluster_nodes n 
join sys.dm_hadr_availability_replica_cluster_states cs 
on n.replica_server_name = cs.replica_server_name 
join sys.dm_hadr_availability_replica_states rs  
on rs.replica_id = cs.replica_id 
 

-- AG Status 
DECLARE @HADRName    varchar(25) 
SET @HADRName = @@SERVERNAME 
select n.group_name,n.replica_server_name,n.node_name,rs.role_desc, 
db_name(drs.database_id) as 'DBName',drs.synchronization_state_desc,drs.synchronization_health_desc 
from sys.dm_hadr_availability_replica_cluster_nodes n 
join sys.dm_hadr_availability_replica_cluster_states cs 
on n.replica_server_name = cs.replica_server_name 
join sys.dm_hadr_availability_replica_states rs  
on rs.replica_id = cs.replica_id 
join sys.dm_hadr_database_replica_states drs 
on rs.replica_id=drs.replica_id 
where n.replica_server_name <> @HADRName


/****** Cluster Name *********************/
select cluster_name,
quorum_state_desc
from sys.dm_hadr_cluster
GO


/******************************/

select ar.replica_server_name,
ars.role_desc,
ar.failover_mode_desc,
ars.synchronization_health_desc,
ars.operational_state_desc,
CASE ars.connected_state
WHEN 0 THEN 'Disconnected'
WHEN 1 THEN 'Connected'
ELSE ''
END as ConnectionState
from sys.dm_hadr_availability_replica_states ars
inner join sys.availability_replicas ar on ars.replica_id = ar.replica_id
and ars.group_id = ar.group_id
GO


/************* Database Status ***********************************/
select distinct rcs.database_name,
ar.replica_server_name,
drs.synchronization_state_desc,
drs.synchronization_health_desc,
CASE rcs.is_failover_ready
WHEN 0 THEN 'Data Loss'
WHEN 1 THEN 'No Data Loss'
ELSE ''
END as FailoverReady
from sys.dm_hadr_database_replica_states drs
inner join sys.availability_replicas ar on drs.replica_id = ar.replica_id
and drs.group_id = ar.group_id
inner join sys.dm_hadr_database_replica_cluster_states rcs on drs.replica_id = rcs.replica_id
order by replica_server_name
go

-- 2012

SELECT
ar.replica_server_name,
adc.database_name,
ag.name AS ag_name,
CASE drs.is_local when 0 then 'No' when 1 then 'Yes' END as is_local,
CASE WHEN hags.primary_replica = ar.replica_server_name THEN 'Yes' ELSE 'No' END AS is_primary_replica, 
drs.synchronization_state_desc, drs.is_commit_participant, drs.synchronization_health_desc, drs.recovery_lsn, 
drs.truncation_lsn, drs.last_sent_lsn, drs.last_sent_time, drs.last_received_lsn, drs.last_received_time, 
drs.last_hardened_lsn, drs.last_hardened_time, drs.last_redone_lsn, drs.last_redone_time, drs.log_send_queue_size as log_send_queue_size_KB, 
drs.log_send_rate as log_send_rate_KBSec, drs.redo_queue_size as redo_queue_size_KB, drs.redo_rate as redo_rate_KB, drs.filestream_send_rate, drs.end_of_log_lsn, 
drs.last_commit_lsn, drs.last_commit_time 
FROM sys.dm_hadr_database_replica_states AS drs 
INNER JOIN sys.availability_databases_cluster AS adc ON drs.group_id = adc.group_id AND drs.group_database_id = adc.group_database_id 
INNER JOIN sys.availability_groups AS ag ON ag.group_id = drs.group_id 
INNER JOIN sys.availability_replicas AS ar ON drs.group_id = ar.group_id AND drs.replica_id = ar.replica_id 
INNER JOIN sys.dm_hadr_availability_group_states AS hags ON hags.group_id = ag.group_id ORDER BY ag.name, ar.replica_server_name, adc.database_name;
go


-- 2014 up	

SELECT 
	ar.replica_server_name, 
	adc.database_name, 
	ag.name AS ag_name, 
	drs.is_local, 
	drs.is_primary_replica, 
	drs.synchronization_state_desc, 
	drs.is_commit_participant, 
	drs.synchronization_health_desc, 
	drs.recovery_lsn, 
	drs.truncation_lsn, 
	drs.last_sent_lsn, 
	drs.last_sent_time, 
	drs.last_received_lsn, 
	drs.last_received_time, 
	drs.last_hardened_lsn, 
	drs.last_hardened_time, 
	drs.last_redone_lsn, 
	drs.last_redone_time, 
	drs.log_send_queue_size, 
	drs.log_send_rate, 
	drs.redo_queue_size, 
	drs.redo_rate, 
	drs.filestream_send_rate, 
	drs.end_of_log_lsn, 
	drs.last_commit_lsn, 
	drs.last_commit_time
FROM sys.dm_hadr_database_replica_states AS drs
INNER JOIN sys.availability_databases_cluster AS adc 
	ON drs.group_id = adc.group_id AND 
	drs.group_database_id = adc.group_database_id
INNER JOIN sys.availability_groups AS ag
	ON ag.group_id = drs.group_id
INNER JOIN sys.availability_replicas AS ar 
	ON drs.group_id = ar.group_id AND 
	drs.replica_id = ar.replica_id
ORDER BY 
	ag.name, 
	ar.replica_server_name, 
	adc.database_name;
go

