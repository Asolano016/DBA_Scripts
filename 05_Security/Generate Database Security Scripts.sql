/******************************************************************************
DATABASE PERMISSIONS REVIEW

PURPOSE

    Review all database roles, schema permissions and object permissions.

OUTPUT

    • Role Membership
    • Database Permissions
    • Schema Permissions
    • Object Permissions

USE CASES

    • Security audits
    • Access reviews
    • SOX reviews
    • Migration validations

******************************************************************************/

USE [SQLInventory]
GO

SET QUOTED_IDENTIFIER OFF
GO

------------------------------------------------------------------------------
-- TEMPORARY TABLE
------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#tDatabaseRoles') IS NOT NULL
	DROP TABLE #tDatabaseRoles

CREATE TABLE #tDatabaseRoles
(
	DatabaseName     SYSNAME,
	LoginName		 SYSNAME,
	LoginType		 VARCHAR(60),
	PermissionScope  VARCHAR(60),
	PermissionSource SYSNAME NULL,
	ObjectName       SYSNAME NULL,
	ObjectType       SYSNAME NULL,
	PermissionName   SYSNAME,
	PermissionState  VARCHAR(60)
);

------------------------------------------------------------------------------
-- GET FOR EACH TABLE
------------------------------------------------------------------------------

DECLARE @DatabaseName SYSNAME;
DECLARE @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR FAST_FORWARD
FOR

SELECT name
FROM sys.databases
WHERE state_desc = 'ONLINE'
AND name NOT IN ('model','tempdb','Admin');

OPEN db_cursor;

FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN

    SET @SQL = "
USE " + QUOTENAME(@DatabaseName) + ";

INSERT INTO #tDatabaseRoles

------------------------------------------------------------------------------
-- DATABASE ROLE MEMBERSHIP
------------------------------------------------------------------------------

SELECT DB_NAME()
      ,dp.name
      ,dp.type_desc
      ,'ROLE'
      ,USER_NAME(rm.role_principal_id)
      ,NULL
      ,NULL
      ,'MEMBER'
      ,'GRANT'
FROM sys.database_role_members rm
INNER JOIN sys.database_principals dp ON rm.member_principal_id = dp.principal_id
WHERE dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')

UNION ALL

------------------------------------------------------------------------------
-- DATABASE LEVEL PERMISSIONS
------------------------------------------------------------------------------

SELECT DB_NAME()
      ,dp.name
      ,dp.type_desc
      ,'DATABASE'
      ,NULL
      ,NULL
      ,NULL
      ,perm.permission_name
      ,perm.state_desc
FROM sys.database_permissions perm
INNER JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
WHERE perm.class_desc = 'DATABASE'
AND dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')

UNION ALL

------------------------------------------------------------------------------
-- SCHEMA LEVEL PERMISSIONS
------------------------------------------------------------------------------

SELECT DB_NAME()
      ,dp.name
      ,dp.type_desc
      ,'SCHEMA'
      ,s.name
      ,NULL
      ,NULL
      ,perm.permission_name
      ,perm.state_desc
FROM sys.database_permissions perm
INNER JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
INNER JOIN sys.schemas s ON perm.major_id = s.schema_id
WHERE perm.class_desc = 'SCHEMA'
AND dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')

UNION ALL

------------------------------------------------------------------------------
-- OBJECT LEVEL PERMISSIONS
------------------------------------------------------------------------------

SELECT DB_NAME()
      ,dp.name
      ,dp.type_desc
      ,'OBJECT'
      ,SCHEMA_NAME(o.schema_id)
      ,o.name
      ,o.type_desc
      ,perm.permission_name
      ,perm.state_desc
FROM sys.database_permissions perm
INNER JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
INNER JOIN sys.objects o ON perm.major_id = o.object_id
WHERE perm.class_desc = 'OBJECT_OR_COLUMN'
AND dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys');
";
    --PRINT @SQL
    EXEC sys.sp_executesql @SQL;

    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

------------------------------------------------------------------------------
-- RESULTS
------------------------------------------------------------------------------

SELECT dr.DatabaseName	
	  ,dr.LoginName	
	  ,dr.LoginType	
	  ,dr.PermissionScope	
	  ,dr.PermissionSource	
	  ,dr.ObjectName
	  ,dr.ObjectType
	  ,dr.PermissionName	
	  ,dr.PermissionState
	  ,CASE PermissionScope
			WHEN 'ROLE' THEN 'USE [' + dr.DatabaseName + ']; ALTER ROLE [' + dr.PermissionSource + '] ADD MEMBER [' + dr.LoginName + '];' -- DATABASE ROLE MEMBERSHIP
			WHEN 'DATABASE' THEN 'USE [' + dr.DatabaseName + '];' + dr.PermissionState + ' ' + dr.PermissionName + ' TO [' + dr.LoginName + '];' -- DATABASE LEVEL PERMISSIONS
			WHEN 'SCHEMA' THEN 'USE [' + dr.DatabaseName + '];' + dr.PermissionState + ' ' + dr.PermissionName + ' ON SCHEMA::[' + dr.PermissionSource + '] TO [' + dr.LoginName + '];' -- SCHEMA LEVEL PERMISSIONS
			WHEN 'OBJECT' THEN 'USE [' + dr.DatabaseName + '];' + dr.PermissionState + ' ' + dr.PermissionName + ' ON [' + dr.PermissionSource + '].[' + dr.ObjectName + '] TO [' + dr.LoginName + '];' -- OBJECT LEVEL PERMISSIONS
	   END AS MigrationScript
FROM #tDatabaseRoles dr
INNER JOIN master.sys.server_principals sp ON dr.LoginName = sp.name
WHERE dr.LoginName NOT LIKE '##%'
AND dr.LoginName NOT IN ('PRG-DC\GS_PRGMSSQLMON$','PRG-DC\UDLDHL-SQLmigdist','PRG-DC\U-DLG-PRGDC-SQL_Admins','public')
AND dr.LoginType <> 'DATABASE_ROLE'
AND dr.PermissionName NOT IN ('CONNECT')
--AND sp.is_disabled = 0
--AND dr.LoginName = 'AndresTest'
ORDER BY dr.LoginName, dr.PermissionScope