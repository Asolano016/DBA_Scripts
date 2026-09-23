/******************************************************************************
LOGIN EXPORT GENERATOR

PURPOSE

    Generate login information and CREATE LOGIN statements
    preserving:

        • Password Hash
        • SID

USE CASES

    • Server migrations
    • DR environments
    • Login synchronization
    • Permission migrations

NOTES

    The generated CREATE LOGIN statements use:

        WITH PASSWORD = HASHED
        SID = ...

******************************************************************************/

USE master;
GO

------------------------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------------------------

DECLARE @LoginFilter VARCHAR(MAX);

-- Examples:
--
-- ''                                  = All SQL Logins
-- 'kad_admin'                         = Single Login
-- 'kad_admin,kad_user,cdr_user'       = Multiple Logins

SET @LoginFilter = '';

------------------------------------------------------------------------------
-- LOGIN INVENTORY
------------------------------------------------------------------------------

SELECT sp.name AS LoginName
      ,sp.type_desc AS LoginType
      ,sp.create_date
      ,sp.modify_date
      ,LOGINPROPERTY(sp.name,'PasswordHash') AS PasswordHash
      ,sp.sid AS LoginSID
      ,'CREATE LOGIN [' + sp.name + '] WITH PASSWORD = 0x' + CONVERT(NVARCHAR(MAX), CONVERT(VARBINARY(MAX),LOGINPROPERTY(sp.name, 'PasswordHash')), 2) + ' HASHED, SID = 0x' + CONVERT(VARCHAR(MAX), sp.sid, 2) + ';' AS CreateLoginStatement
FROM sys.server_principals sp
WHERE sp.type = 'S'                 -- SQL Login
AND sp.name NOT LIKE '##%'
AND sp.name <> 'sa'
AND (ISNULL(@LoginFilter,'') = '' OR sp.name IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@LoginFilter, ',')))
ORDER BY sp.name;
GO