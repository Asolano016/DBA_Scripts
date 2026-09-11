SELECT FORMAT(GETDATE(), 'd/M/yy HH:mm') AS RunTime
	  ,UPPER(ar_primary.replica_server_name ) AS PrimaryReplica
	  ,DB_NAME(drs.database_id) AS DatabaseName
	  ,UPPER(ar_secondary.replica_server_name) AS SecondaryReplica
	  ,DATEDIFF(SECOND, drs_secondary.last_commit_time, drs.last_commit_time) / 3600 AS SyncLagHrs
	  ,(DATEDIFF(SECOND, drs_secondary.last_commit_time, drs.last_commit_time) % 3600) / 60 AS SyncLagMin
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar_primary ON drs.replica_id = ar_primary.replica_id
JOIN sys.availability_groups ag ON ar_primary.group_id = ag.group_id
JOIN sys.dm_hadr_database_replica_states drs_secondary ON drs.group_database_id = drs_secondary.group_database_id AND drs_secondary.is_local = 0
JOIN sys.availability_replicas ar_secondary ON drs_secondary.replica_id = ar_secondary.replica_id
WHERE drs.is_primary_replica = 1
AND DB_NAME(drs.database_id) = 'CargoWiseOneDFOBNJPRO'
ORDER BY DatabaseName, SecondaryReplica;

SELECT UPPER(ar.replica_server_name) replica_server_name
	  ,DB_NAME(drs.database_id) AS database_name
      ,drs.last_hardened_time
      ,drs.last_redone_time
      ,drs.redo_queue_size
      ,drs.log_send_queue_size
FROM sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_replicas ar ON ar.replica_id = drs.replica_id
WHERE is_primary_replica = 0
AND DB_NAME(database_id) = 'CargoWiseOneDFOBNJPRO'
ORDER BY ar.replica_server_name