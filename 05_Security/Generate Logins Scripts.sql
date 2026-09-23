/******************************************************************************
GENERATE LOGIN MIGRATION SCRIPT

PURPOSE

    Generate login migration scripts preserving:

        • SID
        • Password Hash (SQL Logins only)
        • Login Type

SUPPORTED LOGIN TYPES

    S = SQL Login

    U = Windows Login

    G = Windows Group

NOTES

    • System accounts are excluded
    • SQL Logins retain SID and Password Hash
    • Windows accounts retain SID and are recreated
      using FROM WINDOWS

******************************************************************************/

USE master;
GO

SET NOCOUNT ON;

------------------------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------------------------

DECLARE @LoginFilter VARCHAR(MAX);

-- Examples:
--
-- ''                              = All logins
-- 'AndresTest'                    = Single login
-- 'AndresTest,MyAppLogin'         = Multiple logins

SET @LoginFilter = '';

------------------------------------------------------------------------------
-- LOGIN INVENTORY
------------------------------------------------------------------------------

SELECT sp.sid AS LoginSID
      ,sp.name AS LoginName
      ,sp.type_desc AS LoginType
      ,CASE 
          WHEN sp.type = 'S' THEN LOGINPROPERTY(sp.name, 'PasswordHash') 
       END AS PasswordHash
      ,CASE
          WHEN sp.type = 'S' THEN 'CREATE LOGIN ' + QUOTENAME(sp.name) + ' WITH PASSWORD = 0x' + CONVERT(NVARCHAR(MAX), CONVERT(VARBINARY(MAX), LOGINPROPERTY (sp.name, 'PasswordHash')), 2) + ' HASHED, SID = 0x' + CONVERT(VARCHAR(MAX), sp.sid, 2) + ';'
          WHEN sp.type = 'U' THEN 'CREATE LOGIN ' + QUOTENAME(sp.name) + ' FROM WINDOWS;'
          WHEN sp.type = 'G' THEN 'CREATE LOGIN ' + QUOTENAME(sp.name) + ' FROM WINDOWS;'
       END AS CreateLoginStatement
      ,sp.create_date AS CreateDate
      ,sp.modify_date AS ModifyDate
FROM sys.server_principals sp
WHERE sp.type IN ('S','U','G')
AND sp.name NOT LIKE '##%'
AND sp.name NOT LIKE 'NT %'
AND sp.name NOT LIKE 'NT AUTHORITY%'
AND sp.name NOT LIKE 'NT SERVICE%'
AND sp.name NOT IN ('sa')
AND(ISNULL(@LoginFilter,'') = '' OR sp.name IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@LoginFilter, ',')))
ORDER BY sp.type_desc DESC, sp.name;
GO

/******************************************************************************
INTERPRETATION

SQL_LOGIN

    Generates:

        CREATE LOGIN ...
        WITH PASSWORD = HASHED
        SID = ...

    Suitable for migrations.

------------------------------------------------------------------------------

WINDOWS_LOGIN

    Generates:

        CREATE LOGIN ...
        FROM WINDOWS

------------------------------------------------------------------------------

WINDOWS_GROUP

    Generates:

        CREATE LOGIN ...
        FROM WINDOWS

------------------------------------------------------------------------------

COMMON USE CASES

    • Server migrations
    • Disaster recovery
    • Login synchronization
    • Environment refreshes
    • Security reviews

******************************************************************************/