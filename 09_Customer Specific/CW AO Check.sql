REM  connect to CZCHOWV941\CW1PRODCLUCHO before running this
SELECT DBName, datediff(ss,[CZCHOWV941\CW1PRODCLUCHO],[czchows6613]) as Delay_CZCHOWS6613, datediff(ss,[CZCHOWV941\CW1PRODCLUCHO],[czstlws0531]) as Delay_CZSTLWS0531, datediff(ss,[CZCHOWV941\CW1PRODCLUCHO],[CZSTLWV040\CW1PRODCLUSTL]) as Delay_CZSTLWV040 FROM   
(
            SELECT AR.replica_server_name         AS InstanceName, 
                   Db_name(DRS.database_id)       AS DBName, 
                   DRS.last_commit_time
            FROM   sys.dm_hadr_database_replica_states DRS 
            LEFT JOIN sys.availability_replicas AR 
            ON DRS.replica_id = AR.replica_id 
            LEFT JOIN sys.availability_groups AGS 
            ON AR.group_id = AGS.group_id 
            LEFT JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id 
            AND AR.replica_id = HARS.replica_id
                     --where Db_name(DRS.database_id) in ('CargoWiseOneDFOBNJPRO','CargowiseoneDFOBNJPRO_UserRepository')
) t 
PIVOT(
    MAX(last_commit_time) 
    FOR InstanceName  IN (
        [CZCHOWV941\CW1PRODCLUCHO], 
        [czchows6613], 
        [czstlws0531], 
        [CZSTLWV040\CW1PRODCLUSTL])
) AS pivot_table;
