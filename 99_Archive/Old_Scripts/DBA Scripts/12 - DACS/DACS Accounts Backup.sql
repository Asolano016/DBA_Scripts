USE [master]
GO

SET QUOTED_IDENTIFIER OFF
GO

SET QUOTED_IDENTIFIER OFF;

IF OBJECT_ID('tempdb..#tDatabaseRole') IS NOT NULL
DROP TABLE #tDatabaseRole

DECLARE @query NVARCHAR(MAX),
	    @LoginList NVARCHAR(MAX),
	    @SQLLoginCreation NVARCHAR(MAX),
		@WindowsLoginCreation NVARCHAR(MAX),
		@GrantInstanceRoles NVARCHAR(MAX),
		@GrantDatabaseRoles NVARCHAR(MAX),
		@GrantSecurables NVARCHAR(MAX);

CREATE TABLE #tDatabaseRole(
	[SERVER]    VARCHAR(MAX),
	[USERNAME]  VARCHAR(MAX),
	[DBNAME]    VARCHAR(MAX),
	[PRIVILEGE] VARCHAR(MAX),
	[TYPE] CHAR(2)
)

SET @LoginList = "'UserDHLSpl'
			     ,'LOGINNAME'
				 ,'LOGINNAME'
				 ,'LOGINNAME'
				 ,'LOGINNAME'";

SET @SQLLoginCreation =  "SELECT @@SERVERNAME AS Instance
					     ,name As LoginName
					     ,'CREATE LOGIN [' + name + '] WITH PASSWORD = 0x' + CONVERT(NVARCHAR(MAX),CONVERT(VARBINARY(MAX), password),2) + ' HASHED;' AS SQLLoginCreation
				    FROM syslogins
				    WHERE password IS NOT NULL
				    AND  name IN (" + @LoginList + ")"

SET @WindowsLoginCreation = "SELECT @@SERVERNAME AS Instance
					     ,name As LoginName
					     ,'CREATE LOGIN [' + name + '] FROM WINDOWS;' AS WindowsLoginCreation
				    FROM syslogins
				    WHERE password IS NULL
					AND name IN (" + @LoginList + ")"

SET @GrantInstanceRoles = "SELECT @@SERVERNAME As ServerName
						  ,m.name AS LoginName
						  ,r.name AS RoleName
						  ,'ALTER SERVER ROLE [' + r.name + '] ADD MEMBER  [' + m.name + '];' AS GrantInstanceRole
					FROM sys.server_role_members rm
					INNER JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
					INNER JOIN sys.server_principals m ON m.principal_id = rm.member_principal_id
					WHERE m.name IN (" + @LoginList + ")"

SET @GrantSecurables = "SELECT @@SERVERNAME As ServerName
						      ,sp.name AS LoginName
						      ,'GRANT ' + p.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + ' TO [' + sp.name + ']' AS GrantSecurable
						FROM sys.server_principals sp
						INNER JOIN sys.server_permissions p ON p.grantee_principal_id = sp.principal_id AND p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DATABASE','ALTER TRACE')
						WHERE sp.name IN (" + @LoginList + ")"

SET @GrantDatabaseRoles = "USE [?];

			    INSERT INTO #tDatabaseRole
			    SELECT @@SERVERNAME AS Server
			    	  ,l.name AS LoginName
				      ,DB_NAME() AS DatabaseName
			    	  ,r.name AS Rolename
					  ,m.type AS Type
			    FROM sys.database_role_members rm
			    JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
			    JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
				JOIN sys.server_principals s ON s.sid = m.sid
				JOIN master..syslogins l ON l.sid = m.sid
			    WHERE m.name IN (" + @LoginList + ")
			    ORDER BY r.name, m.name"

PRINT @GrantDatabaseRoles

EXEC sp_executesql @SQLLoginCreation
EXEC sp_executesql @WindowsLoginCreation
EXEC sp_executesql @GrantInstanceRoles
EXEC sp_executesql @GrantSecurables
EXEC sp_MSforeachdb @GrantDatabaseRoles

SELECT * FROM #tDatabaseRole

