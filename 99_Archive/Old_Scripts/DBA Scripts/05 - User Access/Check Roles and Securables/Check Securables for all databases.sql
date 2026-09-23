

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @query NVARCHAR(MAX);

IF OBJECT_ID('tempdb..#tDatabaseSecurableRole') IS NOT NULL
DROP TABLE #tDatabaseSecurableRole;

CREATE TABLE #tDatabaseSecurableRole(
	ServerName	   NVARCHAR(250),
	DatabaseName   NVARCHAR(250),
	LoginName	   NVARCHAR(250),
	RoleType	   NVARCHAR(250),
	ClassDesc	   NVARCHAR(250),
	PermissionName NVARCHAR(250),
	State          NVARCHAR(250),
	ObjectName	   NVARCHAR(250),
	ObjectDesc	   NVARCHAR(250)
)

SET @query = "USE [?];

			IF '?' NOT IN ('master','tempdb','model','Admin','msdb')
			BEGIN
				INSERT INTO #tDatabaseSecurableRole
				SELECT @@SERVERNAME AS ServerName
	  ,DB_NAME() AS DatabaseName
      ,d.name AS LoginName
	  ,d.type_desc
	  ,class_desc
	  ,permission_name
	  ,state_desc
	  ,o.name AS ObjectName
	  ,o.type_desc
FROM sys.database_principals d
INNER JOIN sys.database_permissions p ON p.grantee_principal_id = d.principal_id
INNER JOIN sys.objects o ON o.object_id = p.major_id OR o.object_id = p.minor_id
INNER JOIN sys.schemas s on s.schema_id = o.schema_id
AND d.name NOT LIKE '##%'
AND d.name NOT LIKE 'NT %'
AND d.name NOT IN ('RSExecRole','guest','public', 'KUL-DC\UDLMYKUL-QUALYS', 'PRG-DC\U-DLG-PRGDC-SQL_Admins', 'sa')
ORDER BY d.name, o.name
			END"

EXEC sp_MSforeachdb @query

SELECT ServerName
      ,DatabaseName
	  ,LoginName
	  ,RoleType
	  ,ClassDesc
	  ,PermissionName
	  ,State
	  ,ObjectName
	  ,ObjectDesc
FROM #tDatabaseSecurableRole

DROP TABLE #tDatabaseSecurableRole
