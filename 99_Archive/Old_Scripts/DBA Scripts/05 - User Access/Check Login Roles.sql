USE master
GO

SET QUOTED_IDENTIFIER OFF

---------------- DECLARE VARIALES----------------

IF OBJECT_ID('tempdb..#tLoginRole') IS NOT NULL
DROP TABLE #tLoginRole

IF OBJECT_ID('tempdb..#tInstanceLoginRole') IS NOT NULL
DROP TABLE #tInstanceLoginRole

IF OBJECT_ID('tempdb..#tDatabaseLoginRole') IS NOT NULL
DROP TABLE #tDatabaseLoginRole

CREATE TABLE #tInstanceLoginRole(
	ServerName VARCHAR(50),
	LoginName  VARCHAR(50),
	RoleName  VARCHAR(50),
	RoleType VARCHAR(50)
)

CREATE TABLE #tDatabaseLoginRole(
	ServerName VARCHAR(50),
	DatabaseName VARCHAR(50),
	LoginName  VARCHAR(50),
	RoleName  VARCHAR(50),
	RoleType VARCHAR(50)
)

CREATE TABLE #tLoginRole(
	ServerName VARCHAR(50),
	DatabaseName VARCHAR(50),
	LoginName  VARCHAR(50),
	RoleName  VARCHAR(50),
	RoleType VARCHAR(50)
)

DECLARE @query NVARCHAR(MAX)
DECLARE @UserName VARCHAR(255) = 'PHX-DC\srv_phxdc-rmadmin'

----------------INSTANCE ROLE DATA----------------

INSERT INTO #tInstanceLoginRole
SELECT @@SERVERNAME As ServerName
       ,m.name AS LoginName
	   ,r.name AS RoleName
	   ,'Instance-Level Role' 
FROM sys.server_role_members rm
INNER JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
INNER JOIN sys.server_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name NOT LIKE '##%'
AND m.name NOT LIKE 'NT %'
AND m.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa')
AND m.name = @UserName
--ORDER BY m.name,r.name

UNION ALL

SELECT @@SERVERNAME As ServerName
      ,sp.name AS LoginName
      ,CASE 
		WHEN p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DATABASE') 
			THEN 'activity monitor'
		WHEN p.permission_name IN ('ALTER TRACE') 
			THEN 'alter trace'
		ELSE NULL
	   END AS RoleName
	  ,'Instance-Level Role' AS RoleType
FROM sys.server_principals sp
INNER JOIN sys.server_permissions p ON p.grantee_principal_id = sp.principal_id AND p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DATABASE','ALTER TRACE')
WHERE sp.name NOT LIKE '##%'
AND sp.name NOT LIKE 'NT %'
AND sp.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa')
AND sp.type IN ('U','G','S')
AND sp.name = @UserName
GROUP BY sp.name, CASE 
					WHEN p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DATABASE') 
						THEN 'activity monitor'
					WHEN p.permission_name IN ('ALTER TRACE') 
						THEN 'alter trace'
					ELSE NULL
				   END 

----------------DATABASE ROLE DATA----------------

SET @query = "USE [?];

			IF '?' NOT IN ('master','tempdb','model','Admin')
			BEGIN
				INSERT INTO #tDatabaseLoginRole
				SELECT @@SERVERNAME AS ServerName
					  ,DB_NAME() AS DatabaseName
					  ,m.name AS LoginName
					  ,CASE 
						WHEN r.name IN ('SQLAgentOperatorRole','SQLAgentReaderRole','SQLAgentUserRole') 
							THEN 'SQL Agent Role'
						ELSE r.name
					   END AS RoleName
					  ,'Database-Level Role' AS RoleType
				FROM sys.database_role_members rm
				JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
				JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
				JOIN sys.server_principals s ON s.sid = m.sid
				WHERE m.name != 'dbo'
				AND m.name NOT LIKE '%MS_%'
				AND m.type IN ('U','G','S')
				AND m.name = '" + @UserName+  "'
				GROUP BY m.name, CASE 
									WHEN r.name IN ('SQLAgentOperatorRole','SQLAgentReaderRole','SQLAgentUserRole') 
										THEN 'SQL Agent Role'
									ELSE r.name
								 END

			END"

EXEC sp_MSforeachdb @query

----------------DISPLAY DATA----------------

--DROP TABLE #tInstanceLoginRole
--DROP TABLE #tDatabaseLoginRole

INSERT INTO #tLoginRole
SELECT ServerName
	  ,NULL AS DataBaseName
	  ,LoginName
	  ,RoleName
	  ,RoleType
FROM #tInstanceLoginRole
ORDER BY LoginName, RoleName

INSERT INTO #tLoginRole
SELECT ServerName
	  ,DatabaseName
	  ,LoginName 
	  ,RoleName
	  ,RoleType 
FROM #tDatabaseLoginRole
ORDER BY LoginName, RoleName

SELECT * FROM #tLoginRole
ORDER BY LoginName DESC--, RoleType DESC, RoleName DESC

----------------DROP TEMP TABLE----------------

DROP TABLE #tInstanceLoginRole
DROP TABLE #tDatabaseLoginRole
DROP TABLE #tLoginRole