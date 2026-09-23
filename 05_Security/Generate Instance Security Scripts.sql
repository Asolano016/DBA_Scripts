USE [master];
GO

IF OBJECT_ID('tempdb..#tInstanceRoles') IS NOT NULL
    DROP TABLE #tInstanceRoles;

CREATE TABLE #tInstanceRoles (
    InstanceName VARCHAR(128), 
    LoginName SYSNAME,
    LoginType VARCHAR(60),
    IsDisabled BIT,
    RoleName VARCHAR(128)
);

------------------------------------------------------------------------------
-- SERVER ROLES
------------------------------------------------------------------------------

INSERT INTO #tInstanceRoles (InstanceName, LoginName, LoginType, IsDisabled, RoleName)
SELECT @@SERVERNAME
      ,m.name
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

------------------------------------------------------------------------------
-- SERVER PERMISSIONS
------------------------------------------------------------------------------

INSERT INTO #tInstanceRoles (InstanceName, LoginName, LoginType, IsDisabled, RoleName)
SELECT @@SERVERNAME
      ,sp.name
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
-- RESULTS
------------------------------------------------------------------------------

SELECT InstanceName
      ,LoginName
      ,LoginType
      ,IsDisabled
      ,RoleName
      ,CASE
            WHEN RoleName IN ('sysadmin', 'securityadmin', 'serveradmin', 'setupadmin', 'processadmin', 'diskadmin', 'dbcreator', 'bulkadmin') THEN 'ALTER SERVER ROLE '+ QUOTENAME(RoleName) + ' ADD MEMBER ' + QUOTENAME(LoginName) + ';'
            ELSE 'GRANT ' + RoleName + ' TO ' + QUOTENAME(LoginName) + ';'
       END AS MigrationScript
FROM #tInstanceRoles
ORDER BY LoginName, RoleName;