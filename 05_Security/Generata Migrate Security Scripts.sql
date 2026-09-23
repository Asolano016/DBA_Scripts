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

USE [master]
GO

SET QUOTED_IDENTIFIER OFF
GO

------------------------------------------------------------------------------
-- TEMPORARY TABLE
------------------------------------------------------------------------------

DECLARE @LoginFilter VARCHAR(MAX);
/*
-- Examples:
-- ''                              = All logins
-- 'AndresTest'                    = Single login
-- 'AndresTest,MyAppLogin'         = Multiple logins
*/

SET @LoginFilter = '';

IF OBJECT_ID('tempdb..#tDatabaseRoles') IS NOT NULL
	DROP TABLE #tDatabaseRoles;

IF OBJECT_ID('tempdb..#tInstanceRoles') IS NOT NULL
    DROP TABLE #tInstanceRoles;

IF OBJECT_ID('tempdb..#tAccessReview') IS NOT NULL
    DROP TABLE #tAccessReview;

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

CREATE TABLE #tInstanceRoles (
    LoginName SYSNAME,
    LoginType VARCHAR(60),
    IsDisabled BIT,
    RoleName VARCHAR(128)
);

CREATE TABLE #tAccessReview (
    LoginName        SYSNAME,
    LoginType        VARCHAR(100),
    DatabaseName     SYSNAME,
    IsDisabled       BIT NULL,
    AccessScope      VARCHAR(20),
    AccessSummary    VARCHAR(100),
    MigrationScript  NVARCHAR(MAX)
);

------------------------------------------------------------------------------
-- DATABASE PERMISSIONS
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
-- INSTANCE PERMISSIONS
------------------------------------------------------------------------------

-- SERVER ROLES
INSERT INTO #tInstanceRoles (LoginName, LoginType, IsDisabled, RoleName)
SELECT m.name
      ,m.type_desc
      ,m.is_disabled
      ,r.name COLLATE SQL_Latin1_General_CP1_CI_AS
FROM sys.server_role_members rm
INNER JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
INNER JOIN sys.server_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name NOT LIKE '##%'
AND m.name NOT LIKE 'NT %'
AND m.name NOT LIKE '%_TAR'
AND m.type IN ('U','G','S');

-- SERVER PERMISSIONS
INSERT INTO #tInstanceRoles (LoginName, LoginType, IsDisabled, RoleName)
SELECT sp.name
      ,sp.type_desc
      ,sp.is_disabled
      ,p.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
FROM sys.server_principals sp
INNER JOIN sys.server_permissions p ON p.grantee_principal_id = sp.principal_id
WHERE sp.name NOT LIKE '##%'
AND sp.name NOT LIKE 'NT %'
AND sp.name NOT LIKE '%_TAR'
AND sp.type IN ('U','G','S')
AND p.permission_name <> 'CONNECT SQL';

------------------------------------------------------------------------------
-- DATABASE ACCESS
------------------------------------------------------------------------------

INSERT INTO #tAccessReview (LoginName, LoginType, DatabaseName, IsDisabled, AccessScope, AccessSummary, MigrationScript)
SELECT dr.LoginName
      ,CASE dr.LoginType
          WHEN 'SQL_USER' THEN 'SQL_LOGIN'
          WHEN 'WINDOWS_USER' THEN 'WINDOWS_LOGIN'
          ELSE dr.LoginType
       END AS LoginType
      ,dr.DatabaseName	
      ,CAST(sp.is_disabled AS BIT) AS IsDisabled
      ,'DATABASE' AS AccessScope
	  ,CASE dr.PermissionScope
          WHEN 'ROLE' THEN 'Database Role Membership'
          WHEN 'DATABASE' THEN 'Database Permission'
          WHEN 'SCHEMA' THEN 'Schema Permission'
          WHEN 'OBJECT' THEN
                          CASE
                            WHEN dr.PermissionName = 'EXECUTE' THEN 'Stored Procedure Execution'
                            WHEN dr.PermissionName = 'SELECT' THEN 'Table Read Access'
                            WHEN dr.PermissionName = 'INSERT' THEN 'Table Insert Access'
                            WHEN dr.PermissionName = 'UPDATE' THEN 'Table Update Access'
                            WHEN dr.PermissionName = 'DELETE' THEN 'Table Delete Access'
                            ELSE 'Object Permission'
                          END
       END AS AccessSummary
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
AND dr.LoginType IN ('SQL_USER','WINDOWS_USER','WINDOWS_GROUP','EXTERNAL_USER')
AND dr.PermissionName NOT IN ('CONNECT')
--AND sp.is_disabled = 0;

------------------------------------------------------------------------------
-- INSTANCE ACCESS
------------------------------------------------------------------------------

INSERT INTO #tAccessReview (LoginName, LoginType, DatabaseName, IsDisabled, AccessScope, AccessSummary, MigrationScript)
SELECT ir.LoginName
      ,ir.LoginType
      ,'N/A'
      ,ir.IsDisabled
      ,'INSTANCE' AS AccessScope
      ,CASE
			WHEN ir.RoleName IN ('sysadmin','securityadmin','serveradmin','setupadmin','processadmin','diskadmin','dbcreator','bulkadmin') THEN 'Server Role Membership'
            ELSE 'Server Permission'
       END AS AccessSummary
      ,CASE
            WHEN ir.RoleName IN ('sysadmin', 'securityadmin', 'serveradmin', 'setupadmin', 'processadmin', 'diskadmin', 'dbcreator', 'bulkadmin') THEN 'ALTER SERVER ROLE '+ QUOTENAME(ir.RoleName) + ' ADD MEMBER ' + QUOTENAME(ir.LoginName) + ';'
            ELSE 'GRANT ' + ir.RoleName + ' TO ' + QUOTENAME(ir.LoginName) + ';'
       END AS MigrationScript
FROM #tInstanceRoles ir
--WHERE ir.IsDisabled = 0
ORDER BY LoginName, AccessScope;


------------------------------------------------------------------------------
-- LOGIN RESULTS
------------------------------------------------------------------------------

SELECT sp.name AS LoginName
      ,sp.type_desc AS LoginType
      ,sp.is_disabled AS IsDisabled
      /*,CASE 
          WHEN sp.type = 'S' THEN LOGINPROPERTY(sp.name, 'PasswordHash') 
       END AS PasswordHash*/
      ,CASE
          WHEN sp.type = 'S' THEN 'CREATE LOGIN ' + QUOTENAME(sp.name) + ' WITH PASSWORD = 0x' + CONVERT(NVARCHAR(MAX), CONVERT(VARBINARY(MAX), LOGINPROPERTY (sp.name, 'PasswordHash')), 2) + ' HASHED, SID = 0x' + CONVERT(VARCHAR(MAX), sp.sid, 2) + ';'
          WHEN sp.type = 'U' THEN 'CREATE LOGIN ' + QUOTENAME(sp.name) + ' FROM WINDOWS;'
          WHEN sp.type = 'G' THEN 'CREATE LOGIN ' + QUOTENAME(sp.name) + ' FROM WINDOWS;'
       END AS CreateLoginStatement
FROM sys.server_principals sp
WHERE sp.type IN ('S','U','G')
AND sp.name NOT LIKE '##%'
AND sp.name NOT LIKE 'NT %'
AND sp.name NOT LIKE 'NT AUTHORITY%'
AND sp.name NOT LIKE 'NT SERVICE%'
AND sp.name <> 'sa'
AND(ISNULL(@LoginFilter,'') = '' OR sp.name IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@LoginFilter, ',')))
AND sp.is_disabled = 0
ORDER BY sp.type_desc DESC, sp.name;
GO

------------------------------------------------------------------------------
-- PERMISSIONS RESULTS
------------------------------------------------------------------------------

SELECT LoginName
      ,LoginType
      ,DatabaseName
      ,IsDisabled
      ,AccessScope
      ,AccessSummary
      ,MigrationScript 
FROM #tAccessReview
WHERE IsDisabled = 0