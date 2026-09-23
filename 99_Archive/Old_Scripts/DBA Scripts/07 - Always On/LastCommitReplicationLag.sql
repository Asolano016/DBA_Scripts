IF (SELECT role FROM sys.dm_hadr_availability_replica_states WHERE role = 1) = 1
BEGIN
	WITH AGStats AS (
		SELECT r.replica_server_name
			  ,s.role_desc
			  ,DB_NAME(d.database_id) [DBName]
			  ,d.last_commit_time
		FROM   sys.dm_hadr_database_replica_states d 
		INNER JOIN sys.availability_replicas r ON d.replica_id = r.replica_id 
		INNER JOIN sys.dm_hadr_availability_replica_states s ON r.group_id = s.group_id
		AND r.replica_id = s.replica_id 
		AND d.synchronization_health <> 0),
		PriCommitTime AS (SELECT replica_server_name
								,DBName
								,last_commit_time
						  FROM AGStats
						  WHERE	role_desc = 'PRIMARY'),
		SecCommitTime AS (SELECT replica_server_name
								,DBName
								,last_commit_time
						  FROM AGStats
						  WHERE	role_desc = 'SECONDARY')
	SELECT p.replica_server_name [PrimaryReplica]
		  ,p.[DBName] AS [DatabaseName]
		  ,s.replica_server_name [SecondaryReplica]
		  ,p.last_commit_time
		  ,s.last_commit_time
		  ,CONVERT(INT,DATEDIFF(ss,s.last_commit_time,p.last_commit_time)) AS [SyncLagSeconds]
		  ,CONVERT(INT,DATEDIFF(mi,s.last_commit_time,p.last_commit_time)) AS [SyncLagMinutes]
		  ,CONVERT(INT,DATEDIFF(hh,s.last_commit_time,p.last_commit_time)) AS [SyncLagHours]
	FROM PriCommitTime p
	LEFT JOIN SecCommitTime s ON [s].[DBName] = [p].[DBName]
	WHERE s.replica_server_name IS NOT NULL
	AND CONVERT(INT,DATEDIFF(ss,s.last_commit_time,p.last_commit_time)) > 0;
END
