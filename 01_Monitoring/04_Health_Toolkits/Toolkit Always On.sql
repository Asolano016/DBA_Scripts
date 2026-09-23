/******************************************************************************
SQL SERVER ALWAYS ON AVAILABILITY GROUP HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a structured approach for diagnosing Always On Availability
Groups (AG), replica synchronization status, log send & redo queue bottlenecks,
replication latency, listener health, failover readiness, and WSFC cluster quorum.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Availability Group Executive Summary
2. Availability Group Configuration & Primary Replicas
3. Replica Operational & Connection Health
4. Database Replica Synchronization Health
5. Replica Synchronization Mode (Sync vs Async)
6. Log Send Queue Analysis (Transport Bottlenecks)
7. Redo Queue Analysis (Secondary Redo Bottlenecks)
8. Data Movement Status & Suspended Databases
9. Estimated Replication Latency (Send & Redo Delays)
10. Availability Group Listener Configuration
11. Failover Readiness & Commit Participant Status
12. WSFC Cluster Quorum Health
13. Cluster Member Nodes & States
14. HADR Wait Statistics
15. Executive Summary & Always On Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Review Executive Summary (Section 1)
    2. Check Replica Connection & Health States (Section 3 & 4)
    3. Analyze Log Send & Redo Queues (Section 6 & 7)
    4. Validate Failover Readiness & Listeners (Section 10 & 11)

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    AVAILABILITY GROUP EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    Quick Always On health overview across groups, replicas, and databases.

.HEALTHY
    UnhealthyReplicas = 0
    UnsynchronizedDatabases = 0
-----------------------------------------------------------------------------*/

SELECT
    GETDATE() AS CaptureTime,
    (SELECT COUNT(*) FROM sys.availability_groups) AS TotalAvailabilityGroups,
    (SELECT COUNT(*) FROM sys.dm_hadr_availability_replica_states WHERE synchronization_health_desc <> 'HEALTHY') AS UnhealthyReplicas,
    (SELECT COUNT(*) FROM sys.dm_hadr_database_replica_states WHERE synchronization_state_desc NOT IN ('SYNCHRONIZED', 'SYNCHRONIZING')) AS UnhealthyDatabases,
    (SELECT COUNT(*) FROM sys.dm_hadr_database_replica_states WHERE is_suspended = 1) AS SuspendedDatabases;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    AVAILABILITY GROUP CONFIGURATION & PRIMARY REPLICAS
-------------------------------------------------------------------------------
.PURPOSE
    Display AG configuration, automated backup preferences, and failure timeouts.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ag.primary_replica AS PrimaryReplicaServer,
    ag.failure_condition_level AS FailureConditionLevel,
    ag.health_check_timeout AS HealthCheckTimeoutMs,
    ag.automated_backup_preference_desc AS BackupPreference
FROM sys.availability_groups ag;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    REPLICA OPERATIONAL & CONNECTION HEALTH
-------------------------------------------------------------------------------
.PURPOSE
    Validate replica connectivity, operational status, and synchronization health.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS ReplicaServerName,
    ars.role_desc AS CurrentRole,
    ars.connected_state_desc AS ConnectedState,
    ars.operational_state_desc AS OperationalState,
    ars.synchronization_health_desc AS SynchronizationHealth,
    ars.recovery_health_desc AS RecoveryHealth
FROM sys.availability_replicas ar
INNER JOIN sys.dm_hadr_availability_replica_states ars
    ON ar.replica_id = ars.replica_id
INNER JOIN sys.availability_groups ag
    ON ag.group_id = ar.group_id
ORDER BY ag.name, ar.replica_server_name;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    DATABASE REPLICA SYNCHRONIZATION HEALTH
-------------------------------------------------------------------------------
.PURPOSE
    Review AG database synchronization state and local/primary roles.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS ReplicaServerName,
    DB_NAME(drs.database_id) AS DatabaseName,
    drs.is_local AS IsLocalReplica,
    drs.is_primary_replica AS IsPrimaryReplica,
    drs.synchronization_state_desc AS SynchronizationState,
    drs.synchronization_health_desc AS SynchronizationHealth,
    drs.is_suspended AS IsSuspended,
    drs.suspend_reason_desc AS SuspendReason
FROM sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_groups ag
    ON drs.group_id = ag.group_id
INNER JOIN sys.availability_replicas ar
    ON drs.replica_id = ar.replica_id
ORDER BY ag.name, DatabaseName, ar.replica_server_name;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    REPLICA SYNCHRONIZATION MODE (SYNC VS ASYNC)
-------------------------------------------------------------------------------
.PURPOSE
    Validate availability modes, failover modes, and secondary read routing.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS ReplicaServerName,
    ar.availability_mode_desc AS AvailabilityMode,
    ar.failover_mode_desc AS FailoverMode,
    ar.secondary_role_allow_connections_desc AS ReadableSecondarySetting,
    ar.endpoint_url AS EndpointURL
FROM sys.availability_replicas ar
INNER JOIN sys.availability_groups ag
    ON ag.group_id = ar.group_id
ORDER BY ag.name, ar.replica_server_name;
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    LOG SEND QUEUE ANALYSIS (TRANSPORT BOTTLENECKS)
-------------------------------------------------------------------------------
.PURPOSE
    Detect log send queue buildup on the primary replica waiting for network transmission.

.HEALTHY
    log_send_queue_size remains near zero (KB).

.WARNING
    Continuously growing queue size indicates network or secondary I/O bottleneck.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS SecondaryReplicaName,
    DB_NAME(drs.database_id) AS DatabaseName,
    drs.log_send_queue_size AS LogSendQueueKB,
    drs.log_send_rate AS LogSendRateKBPerSec,
    drs.synchronization_state_desc AS SynchronizationState
FROM sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_groups ag
    ON drs.group_id = ag.group_id
INNER JOIN sys.availability_replicas ar
    ON drs.replica_id = ar.replica_id
WHERE drs.is_primary_replica = 0
ORDER BY drs.log_send_queue_size DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 7
    REDO QUEUE ANALYSIS (SECONDARY REDO BOTTLENECKS)
-------------------------------------------------------------------------------
.PURPOSE
    Detect redo queue buildup on secondary replicas.

.HEALTHY
    redo_queue_size remains small.

.WARNING
    Large redo queue delays secondary readability and increases RTO during failovers.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS SecondaryReplicaName,
    DB_NAME(drs.database_id) AS DatabaseName,
    drs.redo_queue_size AS RedoQueueKB,
    drs.redo_rate AS RedoRateKBPerSec,
    drs.synchronization_state_desc AS SynchronizationState
FROM sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_groups ag
    ON drs.group_id = ag.group_id
INNER JOIN sys.availability_replicas ar
    ON drs.replica_id = ar.replica_id
WHERE drs.is_primary_replica = 0
ORDER BY drs.redo_queue_size DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    DATA MOVEMENT STATUS & SUSPENDED DATABASES
-------------------------------------------------------------------------------
.PURPOSE
    Identify databases where HADR data movement is suspended or degraded.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS ReplicaServerName,
    DB_NAME(drs.database_id) AS DatabaseName,
    drs.is_suspended AS IsSuspended,
    drs.suspend_reason_desc AS SuspendReason,
    drs.synchronization_state_desc AS SynchronizationState
FROM sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_groups ag
    ON drs.group_id = ag.group_id
INNER JOIN sys.availability_replicas ar
    ON drs.replica_id = ar.replica_id
WHERE drs.is_suspended = 1
ORDER BY ag.name, DatabaseName;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    ESTIMATED REPLICATION LATENCY (SEND & REDO DELAYS)
-------------------------------------------------------------------------------
.PURPOSE
    Estimate potential data loss (RPO) and recovery time (RTO) in seconds.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS SecondaryReplicaName,
    DB_NAME(drs.database_id) AS DatabaseName,
    drs.log_send_queue_size AS LogSendQueueKB,
    drs.log_send_rate AS LogSendRateKBPerSec,
    CAST(drs.log_send_queue_size AS FLOAT) / NULLIF(drs.log_send_rate, 0) AS EstimatedSendDelaySeconds,
    drs.redo_queue_size AS RedoQueueKB,
    drs.redo_rate AS RedoRateKBPerSec,
    CAST(drs.redo_queue_size AS FLOAT) / NULLIF(drs.redo_rate, 0) AS EstimatedRedoDelaySeconds
FROM sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_groups ag
    ON drs.group_id = ag.group_id
INNER JOIN sys.availability_replicas ar
    ON drs.replica_id = ar.replica_id
WHERE drs.is_primary_replica = 0
ORDER BY EstimatedSendDelaySeconds DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    AVAILABILITY GROUP LISTENER CONFIGURATION
-------------------------------------------------------------------------------
.PURPOSE
    Review AG listener DNS names, TCP ports, and network IP states.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    agl.dns_name AS ListenerDNSName,
    agl.port AS ListenerPort,
    agl.is_conformant AS IsConformant,
    agl.ip_configuration_string_from_cluster AS ClusterIPConfiguration
FROM sys.availability_group_listeners agl
INNER JOIN sys.availability_groups ag
    ON agl.group_id = ag.group_id;
GO

/*-----------------------------------------------------------------------------
    SECTION 11
    FAILOVER READINESS & COMMIT PARTICIPANT STATUS
-------------------------------------------------------------------------------
.PURPOSE
    Determine whether secondary databases are synchronized and ready for failover.
-----------------------------------------------------------------------------*/

SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS ReplicaServerName,
    DB_NAME(drs.database_id) AS DatabaseName,
    drs.is_commit_participant AS IsCommitParticipant,
    drs.synchronization_state_desc AS SynchronizationState,
    drs.synchronization_health_desc AS SynchronizationHealth,
    drs.last_commit_time AS LastCommitTime
FROM sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_groups ag
    ON drs.group_id = ag.group_id
INNER JOIN sys.availability_replicas ar
    ON drs.replica_id = ar.replica_id
ORDER BY ag.name, DatabaseName, ar.replica_server_name;
GO

/*-----------------------------------------------------------------------------
    SECTION 12
    WSFC CLUSTER QUORUM HEALTH
-------------------------------------------------------------------------------
.PURPOSE
    Review Windows Server Failover Cluster (WSFC) quorum state.
-----------------------------------------------------------------------------*/

SELECT
    cluster_name AS ClusterName,
    quorum_type_desc AS QuorumType,
    quorum_state_desc AS QuorumState
FROM sys.dm_hadr_cluster;
GO

/*-----------------------------------------------------------------------------
    SECTION 13
    CLUSTER MEMBER NODES & STATES
-------------------------------------------------------------------------------
.PURPOSE
    Inspect status of all cluster member voting nodes and witness resources.
-----------------------------------------------------------------------------*/

SELECT
    member_name AS MemberName,
    member_type_desc AS MemberType,
    member_state_desc AS MemberState,
    number_of_quorum_votes AS QuorumVotes
FROM sys.dm_hadr_cluster_members
ORDER BY member_name;
GO

/*-----------------------------------------------------------------------------
    SECTION 14
    HADR WAIT STATISTICS
-------------------------------------------------------------------------------
.PURPOSE
    Review wait events associated with Availability Group log transport and commits.
-----------------------------------------------------------------------------*/

SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    max_wait_time_ms,
    CAST(wait_time_ms AS FLOAT) / NULLIF(waiting_tasks_count, 0) AS AvgWaitTimeMs
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'HADR_%'
ORDER BY wait_time_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 15
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    High-level Always On Availability Groups dashboard.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM sys.availability_groups) AS TotalAGs,
    (SELECT COUNT(*) FROM sys.availability_replicas) AS TotalReplicas,
    (SELECT COUNT(*) FROM sys.dm_hadr_availability_replica_states WHERE connected_state_desc <> 'CONNECTED') AS DisconnectedReplicas,
    (SELECT COUNT(*) FROM sys.dm_hadr_database_replica_states WHERE is_suspended = 1) AS SuspendedDatabases,
    (SELECT SUM(log_send_queue_size) FROM sys.dm_hadr_database_replica_states WHERE is_primary_replica = 0) AS TotalLogSendQueueKB,
    (SELECT SUM(redo_queue_size) FROM sys.dm_hadr_database_replica_states WHERE is_primary_replica = 0) AS TotalRedoQueueKB;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
ALWAYS ON SYMPTOM                   ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
Replica Disconnected                --> Check network routing, endpoints, port 5022
Database Suspended (is_suspended=1) --> Resume data movement via ALTER DATABASE ... SET HADR RESUME
High Log Send Queue                 --> Review network bandwidth & secondary storage writes
High Redo Queue                     --> Secondary replica CPU/disk bottleneck; parallel redo
HADR_SYNC_COMMIT High Avg Wait      --> Network round-trip latency between sync replicas
******************************************************************************/


SELECT redo_queue_size

FROM sys.dm_hadr_database_replica_states

ORDER BY database_id;

GO

--------------------------------------------------------------------------------
-- SECTION 9
-- ESTIMATED SYNCHRONIZATION DELAY
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Estimate replication latency.
--
--------------------------------------------------------------------------------

SELECT

    DB_NAME(database_id) AS DatabaseName,

    log_send_queue_size,

    log_send_rate,

    CASE
        WHEN log_send_rate = 0 THEN NULL
        ELSE log_send_queue_size / log_send_rate
    END AS EstimatedSendDelaySeconds

FROM sys.dm_hadr_database_replica_states

ORDER BY EstimatedSendDelaySeconds DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 10
-- LISTENER VALIDATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review listener configuration.
--
--------------------------------------------------------------------------------

SELECT

    dns_name,

    port,

    is_conformant,

    ip_configuration_string_from_cluster

FROM sys.availability_group_listeners;

GO

--------------------------------------------------------------------------------
-- SECTION 11
-- FAILOVER READINESS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Determine databases ready for failover.
--
--------------------------------------------------------------------------------

SELECT

    DB_NAME(database_id) AS DatabaseName,

    synchronization_state_desc,

    synchronization_health_desc,

    is_commit_participant

FROM sys.dm_hadr_database_replica_states

ORDER BY DatabaseName;

GO

--------------------------------------------------------------------------------
-- SECTION 12
-- CLUSTER HEALTH
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review WSFC cluster state.
--
--------------------------------------------------------------------------------

SELECT

    cluster_name,

    quorum_type_desc,

    quorum_state_desc

FROM sys.dm_hadr_cluster;

GO

--------------------------------------------------------------------------------
-- SECTION 13
-- CLUSTER MEMBERS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review cluster nodes.
--
--------------------------------------------------------------------------------

SELECT

    member_name,

    member_type_desc,

    member_state_desc

FROM sys.dm_hadr_cluster_members

ORDER BY member_name;

GO

--------------------------------------------------------------------------------
-- SECTION 14
-- AVAILABILITY REPLICA CONNECTIONS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Validate replica connectivity.
--
--------------------------------------------------------------------------------

SELECT

    ar.replica_server_name,

    ars.connected_state_desc,

    ars.operational_state_desc,

    ars.recovery_health_desc

FROM sys.availability_replicas ar

INNER JOIN sys.dm_hadr_availability_replica_states ars
    ON ar.replica_id = ars.replica_id;

GO

--------