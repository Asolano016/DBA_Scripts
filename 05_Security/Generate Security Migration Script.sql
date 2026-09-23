/******************************************************************************
GENERATE SECURITY MIGRATION SCRIPT

PURPOSE

    Generate security migration scripts for:

        • Server Role Membership
        • Server Permissions
        • Database Users
        • Database Role Membership
        • Database Permissions
        • Schema Permissions
        • Object Permissions

NOTES

    • Generates statements only
    • Does NOT execute anything
    • Intended to be used together with:
        Generate Login Migration Script.sql

******************************************************************************/

USE master;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER OFF;
GO

------------------------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------------------------

DECLARE @PrincipalFilter VARCHAR(MAX);

-- Examples:
--
-- ''                           = All principals
-- 'DOMAIN\Andres'
-- 'DOMAIN\Andres,DOMAIN\DBA'

SET @PrincipalFilter = '';

------------------------------------------------------------------------------
-- RESULTS TABLE
------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#SecurityMigration') IS NOT NULL
    DROP TABLE #SecurityMigration;

CREATE TABLE #SecurityMigration
(
      ScopeType        VARCHAR(50)
    , DatabaseName     SYSNAME NULL
    , PrincipalName    SYSNAME
    , ObjectName       NVARCHAR(500) NULL
    , PermissionName   NVARCHAR(500) NULL
    , GeneratedScript  NVARCHAR(MAX)
);

------------------------------------------------------------------------------
-- SERVER ROLE MEMBERSHIP
------------------------------------------------------------------------------

INSERT INTO #SecurityMigration
(
      ScopeType
    , DatabaseName
    , PrincipalName
    , ObjectName
    , PermissionName
    , GeneratedScript
)

SELECT

      'SERVER_ROLE'

    , NULL

    , m.name

    , r.name

    , NULL

    , 'ALTER SERVER ROLE '
      + QUOTENAME(r.name)
      + ' ADD MEMBER '
      + QUOTENAME(m.name)
      + ';'

FROM sys.server_role_members rm

INNER JOIN sys.server_principals r
    ON rm.role_principal_id = r.principal_id

INNER JOIN sys.server_principals m
    ON rm.member_principal_id = m.principal_id

WHERE m.type IN ('S','U','G')

AND m.name NOT LIKE '##%'

AND m.name NOT LIKE 'NT %'

AND m.name NOT LIKE 'NT AUTHORITY%'

AND m.name NOT LIKE 'NT SERVICE%';

------------------------------------------------------------------------------
-- SERVER PERMISSIONS
------------------------------------------------------------------------------

INSERT INTO #SecurityMigration
(
      ScopeType
    , DatabaseName
    , PrincipalName
    , ObjectName
    , PermissionName
    , GeneratedScript
)

SELECT

      'SERVER_PERMISSION'

    , NULL

    , sp.name

    , NULL

    , perm.permission_name

    , perm.state_desc
      + ' '
      + perm.permission_name
      + ' TO '
      + QUOTENAME(sp.name)
      + ';'

FROM sys.server_permissions perm

INNER JOIN sys.server_principals sp
    ON perm.grantee_principal_id = sp.principal_id

WHERE sp.type IN ('S','U','G')

AND sp.name NOT LIKE '##%'

AND sp.name NOT LIKE 'NT %'

AND sp.name NOT LIKE 'NT AUTHORITY%'

AND sp.name NOT LIKE 'NT SERVICE%';

------------------------------------------------------------------------------
-- DATABASE OBJECTS
------------------------------------------------------------------------------

DECLARE @DatabaseName SYSNAME;
DECLARE @SQL NVARCHAR(MAX);

DECLARE DB_CURSOR CURSOR FAST_FORWARD
FOR

SELECT name
FROM sys.databases
WHERE state_desc = 'ONLINE'
AND name NOT IN
(
      'master'
    , 'model'
    , 'msdb'
    , 'tempdb'
);

OPEN DB_CURSOR;

FETCH NEXT FROM DB_CURSOR
INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN

    SET @SQL = '

    ----------------------------------------------------------------------------
    -- DATABASE USERS
    ----------------------------------------------------------------------------

    INSERT INTO #SecurityMigration

    SELECT

          ''DATABASE_USER''

        , DB_NAME()

        , dp.name

        , NULL

        , NULL

        , ''USE '' + QUOTENAME(DB_NAME()) + '';
CREATE USER ''
          + QUOTENAME(dp.name)
          + '' FOR LOGIN ''
          + QUOTENAME(dp.name)
          + '';''

    FROM sys.database_principals dp

    WHERE dp.type IN (''S'',''U'',''G'')

      AND dp.authentication_type <> 0

      AND dp.name NOT IN
      (
            ''dbo''
          , ''guest''
          , ''sys''
          , ''INFORMATION_SCHEMA''
      );

    ----------------------------------------------------------------------------
    -- DATABASE ROLE MEMBERSHIP
    ----------------------------------------------------------------------------

    INSERT INTO #SecurityMigration

    SELECT

          ''DATABASE_ROLE''

        , DB_NAME()

        , member_principal.name

        , role_principal.name

        , NULL

        , ''USE '' + QUOTENAME(DB_NAME()) + '';
ALTER ROLE ''
          + QUOTENAME(role_principal.name)
          + '' ADD MEMBER ''
          + QUOTENAME(member_principal.name)
          + '';''

    FROM sys.database_role_members drm

    INNER JOIN sys.database_principals role_principal
        ON drm.role_principal_id = role_principal.principal_id

    INNER JOIN sys.database_principals member_principal
        ON drm.member_principal_id = member_principal.principal_id

    WHERE member_principal.name NOT IN
    (
          ''dbo''
        , ''guest''
        , ''sys''
        , ''INFORMATION_SCHEMA''
    );

    ----------------------------------------------------------------------------
    -- DATABASE PERMISSIONS
    ----------------------------------------------------------------------------

    INSERT INTO #SecurityMigration

    SELECT

          ''DATABASE_PERMISSION''

        , DB_NAME()

        , dp.name

        , NULL

        , perm.permission_name

        , ''USE '' + QUOTENAME(DB_NAME()) + '';
''
          + perm.state_desc
          + '' ''
          + perm.permission_name
          + '' TO ''
          + QUOTENAME(dp.name)
          + '';''

    FROM sys.database_permissions perm

    INNER JOIN sys.database_principals dp
        ON perm.grantee_principal_id = dp.principal_id

    WHERE perm.class_desc = ''DATABASE'';

    ----------------------------------------------------------------------------
    -- SCHEMA PERMISSIONS
    ----------------------------------------------------------------------------

    INSERT INTO #SecurityMigration

    SELECT

          ''SCHEMA_PERMISSION''

        , DB_NAME()

        , dp.name

        , s.name

        , perm.permission_name

        , ''USE '' + QUOTENAME(DB_NAME()) + '';
''
          + perm.state_desc
          + '' ''
          + perm.permission_name
          + '' ON SCHEMA::''
          + QUOTENAME(s.name)
          + '' TO ''
          + QUOTENAME(dp.name)
          + '';''

    FROM sys.database_permissions perm

    INNER JOIN sys.database_principals dp
        ON perm.grantee_principal_id = dp.principal_id

    INNER JOIN sys.schemas s
        ON perm.major_id = s.schema_id

    WHERE perm.class_desc = ''SCHEMA'';

    ----------------------------------------------------------------------------
    -- OBJECT PERMISSIONS
    ----------------------------------------------------------------------------

    INSERT INTO #SecurityMigration

    SELECT

          ''OBJECT_PERMISSION''

        , DB_NAME()

        , dp.name

        , QUOTENAME(SCHEMA_NAME(o.schema_id))
          + ''.''
          + QUOTENAME(o.name)

        , perm.permission_name

        , ''USE '' + QUOTENAME(DB_NAME()) + '';
''
          + perm.state_desc
          + '' ''
          + perm.permission_name
          + '' ON ''
          + QUOTENAME(SCHEMA_NAME(o.schema_id))
          + ''.''
          + QUOTENAME(o.name)
          + '' TO ''
          + QUOTENAME(dp.name)
          + '';''

    FROM sys.database_permissions perm

    INNER JOIN sys.database_principals dp
        ON perm.grantee_principal_id = dp.principal_id

    INNER JOIN sys.objects o
        ON perm.major_id = o.object_id

    WHERE perm.class_desc = ''OBJECT_OR_COLUMN'';
    ';

    EXEC sp_executesql @SQL;

    FETCH NEXT FROM DB_CURSOR
    INTO @DatabaseName;

END

CLOSE DB_CURSOR;
DEALLOCATE DB_CURSOR;

------------------------------------------------------------------------------
-- FILTER USERS
------------------------------------------------------------------------------

IF ISNULL(@PrincipalFilter,'') <> ''
BEGIN

    DELETE
    FROM #SecurityMigration
    WHERE PrincipalName NOT IN
    (
        SELECT LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@PrincipalFilter, ',')
    );

END

------------------------------------------------------------------------------
-- RESULTS
------------------------------------------------------------------------------

SELECT

      ScopeType

    , DatabaseName

    , PrincipalName

    , ObjectName

    , PermissionName

    , GeneratedScript

FROM #SecurityMigration

ORDER BY

      PrincipalName
    , DatabaseName
    , ScopeType
    , ObjectName
    , PermissionName;

GO