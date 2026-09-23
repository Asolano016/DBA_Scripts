--**--**--**--**--Backup Specific Database User Access--**--**--**--**--

USE [DatabaseName]
GO

--DROP TEMP TABLES

IF OBJECT_ID('tempdb..##tGrantAccess') IS NOT NULL
DROP TABLE ##tGrantAccess

IF OBJECT_ID('tempdb..##tGrantRoles') IS NOT NULL
DROP TABLE ##tGrantRoles

IF OBJECT_ID('tempdb..##tGrantObject') IS NOT NULL
DROP TABLE ##tGrantObject

--CREATE TEMP TABLES

CREATE TABLE ##tGrantAccess(
Id INT IDENTITY(1,1),
GrantAccess VARCHAR(255)
)

CREATE TABLE ##tGrantRoles(
Id INT IDENTITY(1,1),
GrantRoles VARCHAR(255)
)

CREATE TABLE ##tGrantObject(
Id INT IDENTITY(1,1),
GrantObject VARCHAR(255)
)
--GRANT USER ACCESS
INSERT INTO ##tGrantAccess
SELECT 'EXEC [sp_grantdbaccess] @loginame =['+ ms.[loginname] + '], @name_in_db =['+ s.name +']' AS 'GrantAccess' 
FROM sysusers s
INNER JOIN master.dbo.syslogins ms ON s.sid = ms.sid
WHERE s.name != 'dbo'

--GRANT USER ROLES
INSERT INTO ##tGrantRoles
SELECT 'EXEC sp_addrolemember ' + '@rolename=['+r.name+ '], @membername= ['+ m.name +']' AS 'GrantRoles'
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
WHERE m.name != 'dbo'
ORDER BY r.name, m.name

--GRANT OBJECT LEVEL PERMISSION
INSERT INTO ##tGrantObject
SELECT p.state_desc + ' ' + p.permission_name + ' ON [' + s.name +'].['+ o.name collate Latin1_general_CI_AS+ '] TO [' + u.name collate Latin1_general_CI_AS + ']' AS 'GrantObject'
FROM sys.database_permissions p 
INNER JOIN sys.objects o ON p.major_id = o.object_id 
INNER JOIN sys.schemas s ON s.schema_id = o.schema_id 
INNER JOIN sys.database_principals u ON p.grantee_principal_id = u.principal_id

--SELECT TEMP TABLES
--SELECT * FROM ##tGrantAccess
--SELECT * FROM ##tGrantRoles
--SELECT * FROM ##tGrantObject

--COUNT ROWS

--DECLARE @countAcces INT,
--	    @countRoles INT,
--		@countObject INT

--SET @countAcces = (SELECT COUNT(*) FROM ##tGrantAccess)
--SET @countRoles = (SELECT COUNT(*) FROM ##tGrantRoles)
--SET @countObject = (SELECT COUNT(*) FROM ##tGrantObject)

DECLARE @counter INT = 1,
        @query NVARCHAR(255)

WHILE @counter <= (SELECT COUNT(*) FROM ##tGrantAccess)
BEGIN
    
	SET @query = (SELECT GrantAccess FROM ##tGrantAccess WHERE Id = @counter)

	EXEC sp_executesql @query

	SET @counter = @counter + 1;
END
