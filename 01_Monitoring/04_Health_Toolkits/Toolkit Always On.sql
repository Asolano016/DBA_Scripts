/******************************************************************************
SQL SERVER ALWAYS ON AVAILABILITY GROUP HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

PURPOSE

This toolkit helps identify:

1. Availability Group health status
2. Replica synchronization issues
3. Database synchronization lag
4. Send/redo bottlenecks
5. Failover readiness
6. Data movement issues
7. Availability replica health
8. Availability database health
9. Listener validation
10. Log send queue pressure
11. Redo queue pressure
12. Overall Always On health

RECOMMENDED TROUBLESHOOTING FLOW

    1. Executive Summary
    2. Availability Group Overview
    3. Replica Health
    4. Database Health
    5. Synchronization Status
    6. Log Send Queue Analysis
    7. Redo Queue Analysis
    8. Data Movement Status
    9. Listener Validation
    10. Failover Readiness
    11. Cluster Health
    12. Error Investigation
    13. Triage Indicators

******************************************************************************/

--------------------------------------------------------------------------------
-- SECTION 1
-- EXECUTIVE SUMMARY
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Quick Always On health overview.
--
-- HEALTHY
--
--     All replicas healthy.
--     Databases synchronized.
--     No queues growing.
--
-- INVESTIGATE
--
--     NOT_HEALTHY replicas.
--     Large send queues.
--     Large redo queues.
--
--------------------------------------------------------------------------------

SELECT

    GETDATE() AS CaptureTime,

    (SELECT COUNT(*)
     FROM sys.availability_groups) AS AvailabilityGroups,

    (SELECT COUNT(*)
     FROM sys.dm_hadr_availability_replica_states
     WHERE synchronization_health_desc <> 'HEALTHY') AS UnhealthyReplicas,

    (SELECT COUNT(*)
     FROM sys.dm_hadr_database_replica_states
     WHERE synchronization_state_desc <> 'SYNCHRONIZED') AS UnsynchronizedDatabases;

GO

--------------------------------------------------------------------------------
-- SECTION 2
-- AVAILABILITY GROUP OVERVIEW
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Display AG configuration.
--
--------------------------------------------------------------------------------

SELECT

    ag.name AS AvailabilityGroup,

    ag.primary_replica,

    ag.failure_condition_level,

    ag.health_check_timeout

FROM sys.availability_groups ag;

GO

--------------------------------------------------------------------------------
-- SECTION 3
-- REPLICA HEALTH
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Validate replica health status.
--
--------------------------------------------------------------------------------

SELECT

    ag.name AS AvailabilityGroup,

    ar.replica_server_name,

    ars.role_desc,

    ars.operational_state_desc,

    ars.connected_state_desc,

    ars.synchronization_health_desc

FROM sys.availability_replicas ar

INNER JOIN sys.dm_hadr_availability_replica_states ars
    ON ar.replica_id = ars.replica_id

INNER JOIN sys.availability_groups ag
    ON ag.group_id = ar.group_id

ORDER BY ag.name,
         ar.replica_server_name;

GO

--------------------------------------------------------------------------------
-- SECTION 4
-- DATABASE HEALTH
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review AG database status.
--
--------------------------------------------------------------------------------

SELECT

    ag.name,

    DB_NAME(drs.database_id) AS DatabaseName,

    drs.is_local,

    drs.is_primary_replica,

    drs.synchronization_state_desc,

    drs.synchronization_health_desc

FROM sys.dm_hadr_database_replica_states drs

INNER JOIN sys.availability_groups ag
    ON drs.group_id = ag.group_id

ORDER BY DatabaseName;

GO

--------------------------------------------------------------------------------
-- SECTION 5
-- SYNCHRONIZATION STATUS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Validate synchronization mode and state.
--
--------------------------------------------------------------------------------

SELECT

    ag.name,

    ar.replica_server_name,

    ar.availability_mode_desc,

    ars.role_desc,

    ars.synchronization_health_desc

FROM sys.availability_replicas ar

INNER JOIN sys.dm_hadr_availability_replica_states ars
    ON ar.replica_id = ars.replica_id

INNER JOIN sys.availability_groups ag
    ON ag.group_id = ar.group_id;

GO

--------------------------------------------------------------------------------
-- SECTION 6
-- LOG SEND QUEUE ANALYSIS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Detect transport bottlenecks.
--
--
-- HEALTHY
--
--     Queue remains near zero.
--
-- WARNING
--
--     Continuously growing queues.
--
--------------------------------------------------------------------------------

SELECT

    DB_NAME(database_id) AS DatabaseName,

    log_send_queue_size,

    log_send_rate,

    synchronization_state_desc

FROM sys.dm_hadr_database_replica_states

ORDER BY log_send_queue_size DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 7
-- REDO QUEUE ANALYSIS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Detect redo bottlenecks on secondary replicas.
--
--
-- HEALTHY
--
--     Small redo queue.
--
--------------------------------------------------------------------------------

SELECT

    DB_NAME(database_id) AS DatabaseName,

    redo_queue_size,

    redo_rate,

    synchronization_state_desc

FROM sys.dm_hadr_database_replica_states

ORDER BY redo_queue_size DESC;

GO

--------------------------------------------------------------------------------
-- SECTION 8
-- DATA MOVEMENT STATUS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Verify HADR data movement.
--
--------------------------------------------------------------------------------

SELECT

    DB_NAME(database_id) AS DatabaseName,

    is_primary_replica,

    synchronization_state_desc,

    synchronization_health_desc,

    log_send_queue_size,

    redo_queue_size

FROM sys.dm_hadr_database_replica_states

ORDER BY DatabaseName;

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