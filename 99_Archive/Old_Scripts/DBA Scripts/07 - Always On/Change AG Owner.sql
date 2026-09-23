USE [master]
GO

--Endpoints
DECLARE @accountToDelete VARCHAR(255),
		@serviceOwner VARCHAR(255);
SET @accountToDelete = 'PRG-DC\operator_mafalta'
SET @serviceOwner    = (SELECT service_account FROM sys.dm_server_services WHERE servicename = 'SQL Server (MSSQLSERVER)') 
 
SELECT @@SERVERNAME AS server_name
	  ,pm.class
	  ,pm.class_desc
	  ,pm.[permission_name]
	  ,pm.[state]
	  ,pm.state_desc
	  ,pr.[name] AS [owner]
	  ,gr.[name] AS grantee
	  ,e.[name] AS endpoint_name
	  ,'ALTER AUTHORIZATION ON ENDPOINT::' + e.[name] + ' TO [' + @serviceOwner + '];' AS alter_authorization
	  ,'GRANT ' + pm.[permission_name] + ' ON ENDPOINT::' + e.[name] COLLATE SQL_Latin1_General_CP1_CI_AS  + ' TO [' + gr.[name] + '];' as grant_permission
FROM sys.server_permissions pm 
   JOIN sys.server_principals pr ON pm.grantor_principal_id = pr.principal_id
   JOIN sys.server_principals gr ON pm.grantee_principal_id = gr.principal_id
   JOIN sys.endpoints e ON pm.grantor_principal_id = e.principal_id AND pm.major_id = e.endpoint_id
WHERE pr.[name] = @accountToDelete;

--Availability Group
SELECT @@SERVERNAME AS server_name
	  ,ag.[name] AS AG_name
	  ,p.[name] as owner_name 
	  ,'ALTER AUTHORIZATION ON AVAILABILITY GROUP::' + ag.[name] + ' TO [' + @serviceOwner + '];' AS alter_authorization_ag
FROM sys.availability_groups ag 
   JOIN sys.availability_replicas r ON ag.group_id = r.group_id
   JOIN sys.server_principals p ON r.owner_sid = p.[sid]
WHERE p.[name] = @accountToDelete;
--------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------------------
SELECT @@SERVERNAME AS server_name
	  ,pm.class
	  ,pm.class_desc
	  ,pm.[permission_name]
	  ,pm.[state]
	  ,pm.state_desc
	  ,pr.[name] AS [owner]
	  ,gr.[name] AS grantee
	  ,e.[name] AS endpoint_name
FROM sys.server_permissions pm 
   JOIN sys.server_principals pr ON pm.grantor_principal_id = pr.principal_id
   JOIN sys.server_principals gr ON pm.grantee_principal_id = gr.principal_id
   JOIN sys.endpoints e ON pm.grantor_principal_id = e.principal_id AND pm.major_id = e.endpoint_id
WHERE pr.[name] = @serviceOwner;

SELECT @@SERVERNAME AS server_name
	  ,ag.[name] AS AG_name
	  ,p.[name] as owner_name 
FROM sys.availability_groups ag 
   JOIN sys.availability_replicas r ON ag.group_id = r.group_id
   JOIN sys.server_principals p ON r.owner_sid = p.[sid]
   WHERE p.[name] = @serviceOwner;