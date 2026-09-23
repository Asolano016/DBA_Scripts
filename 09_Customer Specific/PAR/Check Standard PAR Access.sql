/******************************************************************************
DATABASE / INSTANCE ACCESS SUMMARY

PURPOSE

    Display a compact PAR-style access report showing whether a login has:

        OWN   = db_owner
        READ  = db_datareader
        WRITE = db_datawriter
        EXEC  = EXECUTE granted at DATABASE scope
        CRE   = dbcreator
        BULK  = [BULK]admin
        AGE   = SQL Agent roles
        SSIS  = SSIS administrative roles

NOTES

    A value of X means the access exists in at least one database.

******************************************************************************/

USE master;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER OFF;
GO

IF OBJECT_ID('tempdb..#tAccessSummary') IS NOT NULL
    DROP TABLE #tAccessSummary;

CREATE TABLE #tAccessSummary
(
    LoginName NVARCHAR(256),
    OWN  CHAR(1) DEFAULT '-',
    [READ] CHAR(1) DEFAULT '-',
    WRITE CHAR(1) DEFAULT '-',
    [EXEC] CHAR(1) DEFAULT '-',
    CRE  CHAR(1) DEFAULT '-',
    [BULK] CHAR(1) DEFAULT '-',
    AGE  CHAR(1) DEFAULT '-',
    SSIS CHAR(1) DEFAULT '-'
);

------------------------------------------------------------------------------
-- SEED LOGIN LIST
------------------------------------------------------------------------------

INSERT INTO #tAccessSummary (LoginName)
SELECT DISTINCT name
FROM sys.server_principals
WHERE type IN ('U','G','S')
AND name NOT LIKE '##%'
AND name NOT LIKE 'NT %'
AND name NOT IN
('sa', 'KUL-DC\UDLMYKUL-QUALYS', 'PRG-DC\U-DLG-PRGDC-SQL_Admins');

------------------------------------------------------------------------------
-- INSTANCE ROLES
------------------------------------------------------------------------------

UPDATE A
SET CRE = 'X'
FROM #tAccessSummary A
WHERE EXISTS (SELECT 1
              FROM sys.server_role_members rm
              INNER JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
              INNER JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
              WHERE r.name = 'dbcreator'
              AND m.name = A.LoginName);

UPDATE A
SET [BULK] = 'X'
FROM #tAccessSummary A
WHERE EXISTS (SELECT 1
              FROM sys.server_role_members rm
              INNER JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
              INNER JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
              WHERE r.name = '[BULK]admin'
              AND m.name = A.LoginName);

------------------------------------------------------------------------------
-- DATABASE ROLES AND [EXEC]UTE
------------------------------------------------------------------------------

DECLARE @DatabaseName SYSNAME;
DECLARE @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR FAST_FORWARD
FOR

SELECT name
FROM sys.databases
WHERE state_desc = 'ONLINE'
AND name NOT IN
('master','model','msdb','tempdb','Admin');

OPEN db_cursor;

FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN

    SET @SQL = "
    --------------------------------------------------------------------------
    -- DB_OWNER
    --------------------------------------------------------------------------

    UPDATE A
    SET OWN = 'X'
    FROM #tAccessSummary A
    WHERE EXISTS (SELECT 1
                  FROM " + QUOTENAME(@DatabaseName) + ".sys.database_role_members rm
                  INNER JOIN " + QUOTENAME(@DatabaseName) + ".sys.database_principals r ON rm.role_principal_id = r.principal_id
                  INNER JOIN " + QUOTENAME(@DatabaseName) + ".sys.database_principals m ON rm.member_principal_id = m.principal_id
                  WHERE r.name = 'db_owner'
                  AND m.name = A.LoginName);

    --------------------------------------------------------------------------
    -- DB_DATAREADER
    --------------------------------------------------------------------------

    UPDATE A
    SET [READ] = 'X'
    FROM #tAccessSummary A
    WHERE EXISTS (SELECT 1
                  FROM " + QUOTENAME(@DatabaseName) + ".sys.database_role_members rm
                  INNER JOIN " + QUOTENAME(@DatabaseName) + ".sys.database_principals r ON rm.role_principal_id = r.principal_id
                  INNER JOIN " + QUOTENAME(@DatabaseName) + ".sys.database_principals m ON rm.member_principal_id = m.principal_id
                  WHERE r.name = 'db_datareader'
                  AND m.name = A.LoginName);

    --------------------------------------------------------------------------
    -- DB_DATAWRITER
    --------------------------------------------------------------------------

    UPDATE A
    SET WRITE = 'X'
    FROM #tAccessSummary A
    WHERE EXISTS (SELECT 1
                  FROM " + QUOTENAME(@DatabaseName) + ".sys.database_role_members rm
                  INNER JOIN " + QUOTENAME(@DatabaseName) + ".sys.database_principals r ON rm.role_principal_id = r.principal_id
                  INNER JOIN " + QUOTENAME(@DatabaseName) + ".sys.database_principals m ON rm.member_principal_id = m.principal_id
                  WHERE r.name = 'db_datawriter'
                  AND m.name = A.LoginName);

    --------------------------------------------------------------------------
    -- DATABASE EXECUTE
    --------------------------------------------------------------------------

    UPDATE A
    SET [EXEC] = 'X'
    FROM #tAccessSummary A
    WHERE EXISTS (SELECT 1
                  FROM " + QUOTENAME(@DatabaseName) + ".sys.database_permissions perm
                  INNER JOIN " + QUOTENAME(@DatabaseName) + ".sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
                  WHERE dp.name = A.LoginName
                  AND perm.class_desc = 'DATABASE'
                  AND perm.permission_name = 'EXECUTE'
                  AND perm.state_desc = 'GRANT');
";

    EXEC sys.sp_EXECutesql @SQL;

    FETCH NEXT FROM db_cursor INTO @DatabaseName;

END

CLOSE db_cursor;
DEALLOCATE db_cursor;

------------------------------------------------------------------------------
-- SQL AGENT ROLES (MSDB)
------------------------------------------------------------------------------

UPDATE A
SET AGE = 'X'
FROM #tAccessSummary A
WHERE EXISTS (SELECT 1 
              FROM msdb.sys.database_role_members rm
              INNER JOIN msdb.sys.database_principals r ON rm.role_principal_id = r.principal_id
              INNER JOIN msdb.sys.database_principals m ON rm.member_principal_id = m.principal_id
              WHERE r.name IN ('SQLAgentOperatorRole','SQLAgent[READ]erRole','SQLAgentUserRole')
              AND m.name = A.LoginName);

------------------------------------------------------------------------------
-- SSIS ROLES (MSDB)
------------------------------------------------------------------------------

UPDATE A
SET SSIS = 'X'
FROM #tAccessSummary A
WHERE EXISTS (SELECT 1 
              FROM msdb.sys.database_role_members rm
              INNER JOIN msdb.sys.database_principals r ON rm.role_principal_id = r.principal_id
              INNER JOIN msdb.sys.database_principals m ON rm.member_principal_id = m.principal_id
              WHERE r.name = 'db_ssisadmin'
              AND m.name = A.LoginName);

------------------------------------------------------------------------------
-- SSISDB (OPTIONAL)
------------------------------------------------------------------------------

IF DB_ID('SSISDB') IS NOT NULL
BEGIN
    UPDATE A
    SET SSIS = 'X'
    FROM #tAccessSummary A
    WHERE EXISTS (SELECT 1
                  FROM SSISDB.sys.database_role_members rm
                  INNER JOIN SSISDB.sys.database_principals r ON rm.role_principal_id = r.principal_id
                  INNER JOIN SSISDB.sys.database_principals m ON rm.member_principal_id = m.principal_id
                  WHERE r.name = 'ssis_admin'
                  AND m.name = A.LoginName);
END

------------------------------------------------------------------------------
-- RESULTS
------------------------------------------------------------------------------

SELECT @@SERVERNAME AS 'InstanceName'
      ,[LoginName]
      ,[OWN]
      ,[CRE]
      ,[BULK]
      ,[READ]
      ,[WRITE]
      ,[EXEC]
      ,[AGE]
      ,[SSIS]
FROM #tAccessSummary
ORDER BY LoginName;
GO