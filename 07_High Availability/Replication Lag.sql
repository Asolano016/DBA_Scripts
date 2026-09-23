/******************************************************************************
ALWAYSON REPLICATION LAG REVIEW

PURPOSE

    Review AlwaysOn replication latency and identify the source
    of synchronization delays.

OUTPUT

    • Availability Group
    • Database Name
    • Replica Name
    • Replica Role
    • Synchronization State
    • Synchronization Health
    • Commit Lag
    • Log Send Queue
    • Redo Queue
    • Last Hardened Time
    • Last Redone Time
    • Assessment

******************************************************************************/

SET NOCOUNT ON;
GO

IF SERVERPROPERTY('IsHadrEnabled') <> 1
BEGIN
    RAISERROR('Always On Availability Groups is not enabled.',16,1);
    RETURN;
END
GO

;WITH ReplicaInfo AS
(
    SELECT

          ag.name AS AvailabilityGroupName

        , ar.replica_server_name

        , DB_NAME(drs.database_id) AS DatabaseName

        , ars.role_desc

        , drs.synchronization_state_desc

        , drs.synchronization_health_desc

        , drs.last_commit_time

        , drs.last_hardened_time

        , drs.last_redone_time

        , drs.log_send_queue_size

        , drs.redo_queue_size

    FROM sys.dm_hadr_database_replica_states drs

    INNER JOIN sys.availability_replicas ar
        ON drs.replica_id = ar.replica_id

    INNER JOIN sys.dm_hadr_availability_replica_states ars
        ON drs.replica_id = ars.replica_id

    INNER JOIN sys.availability_groups ag
        ON ar.group_id = ag.group_id
),
PrimaryReplica AS
(
    SELECT

          AvailabilityGroupName

        , DatabaseName

        , replica_server_name AS PrimaryReplica

        , last_commit_time AS PrimaryLastCommit

    FROM ReplicaInfo

    WHERE role_desc = 'PRIMARY'
)

SELECT

      r.AvailabilityGroupName

    , r.DatabaseName

    , p.PrimaryReplica

    , r.replica_server_name AS ReplicaName

    , r.role_desc AS ReplicaRole

    , p.PrimaryLastCommit

    , r.last_commit_time AS ReplicaLastCommit

    , DATEDIFF
      (
          SECOND,
          r.last_commit_time,
          p.PrimaryLastCommit
      ) AS CommitLagSeconds

    , CAST
      (
          DATEDIFF
          (
              SECOND,
              r.last_commit_time,
              p.PrimaryLastCommit
          ) / 60.0

          AS DECIMAL(18,2)
      ) AS CommitLagMinutes

    , CAST
      (
          DATEDIFF
          (
              SECOND,
              r.last_commit_time,
              p.PrimaryLastCommit
          ) / 3600.0

          AS DECIMAL(18,2)
      ) AS CommitLagHours

    , r.log_send_queue_size

    , CAST
      (
          r.log_send_queue_size / 1024.0
          AS DECIMAL(18,2)
      ) AS LogSendQueueMB

    , r.redo_queue_size

    , CAST
      (
          r.redo_queue_size / 1024.0
          AS DECIMAL(18,2)
      ) AS RedoQueueMB

    , r.last_hardened_time

    , r.last_redone_time

    , r.synchronization_state_desc

    , r.synchronization_health_desc

    , CASE

          WHEN r.role_desc = 'PRIMARY'
              THEN 'Primary Replica'

          WHEN r.synchronization_health_desc <> 'HEALTHY'
              THEN 'Synchronization Issue'

          WHEN r.log_send_queue_size > 0
               AND r.redo_queue_size = 0
              THEN 'Transport Lag'

          WHEN r.redo_queue_size > 0
              THEN 'Redo Lag'

          WHEN DATEDIFF
               (
                   SECOND,
                   r.last_commit_time,
                   p.PrimaryLastCommit
               ) > 60
              THEN 'Commit Lag'

          ELSE 'Healthy'

      END AS Assessment

FROM ReplicaInfo r

INNER JOIN PrimaryReplica p
    ON r.AvailabilityGroupName = p.AvailabilityGroupName
   AND r.DatabaseName          = p.DatabaseName

ORDER BY

      r.AvailabilityGroupName
    , r.DatabaseName
    , r.role_desc DESC
    , r.replica_server_name;
GO