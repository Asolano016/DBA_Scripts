--STANDARD

/*
DESCRIPTION: Check logins in the instance that could has standard access in relation of the PAR system, 
this script won´t show the access per database, but it will be executed over all the database to check if a login has a standar access
*/

USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

--**--**--CREATE TEMPORARY TABLES AND DECLARE VARIABLES--**--**--

DECLARE @sql NVARCHAR(MAX);

IF OBJECT_ID('tempdb..#tempAccess', 'U') IS NOT NULL
	DROP TABLE #tempAccess

CREATE TABLE #tempAccess (
--[db_name] NVARCHAR(150),
[user_name] NVARCHAR(150),
[role_name] NVARCHAR(50),
[type_desc] NVARCHAR(25)
)

DECLARE @tDbUsrRoles TABLE(
[user_name] NVARCHAR(100),
type_desc VARCHAR(25),
OWN CHAR(2),
[READ] CHAR(2),
DTS CHAR(2),
AGE CHAR(2)
)

DECLARE @tInstUsrRole TABLE(
[user_name] NVARCHAR(100),
type_desc VARCHAR(25),
CRE CHAR(2),
[BULK] CHAR(2)
)

--**--**--EXTRACT DATA FOR EACH DATABASE--**--**--

 SET @sql = "USE [?];

			 IF '?' NOT IN ('master','tempdb','Admin')
			 BEGIN
				 INSERT INTO #tempAccess
				 SELECT --'?' AS [db_name]
					   dpu.name AS [user_name]
					   ,dpr.name AS [role_name]
					   ,dpu.type_desc
				 FROM sys.database_principals  dpr
				 INNER JOIN sys.database_role_members drm ON drm.role_principal_id = dpr.principal_id AND dpr.type = 'R'
				 INNER JOIN sys.database_principals dpu ON dpu.principal_id = drm.member_principal_id AND dpu.type != 'R'
				 WHERE dpu.name NOT LIKE '##%'
				 AND dpu.name NOT LIKE 'NT %'
				 AND dpu.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa','dbo')
				 AND dpr.name NOT IN ('RSExecRole')
				 ORDER BY dpu.name, dpr.type
			  END"

EXEC sp_MSforeachdb @sql

--**--**--LOAD VARIABLES TABLES--**--**--

INSERT INTO @tDbUsrRoles
SELECT [user_name]
	  ,[type_desc]
	  ,CASE 
		WHEN db_owner IS NOT NULL THEN 'X'
		ELSE '-'
	   END OWN
	  ,CASE 
		WHEN db_datareader IS NOT NULL THEN 'X'
		ELSE '-'
	   END [READ]
	  ,CASE 
		WHEN db_ssisadmin IS NOT NULL THEN 'X'
		ELSE '-'
	   END DTS
	  ,CASE 
		WHEN SQLAgentOperatorRole IS NOT NULL THEN 'X'
		WHEN SQLAgentUserRole IS NOT NULL THEN 'X'
		WHEN SQLAgentReaderRole IS NOT NULL THEN 'X'
		ELSE '-'
	   END AGE
FROM (SELECT DISTINCT(role_name)
     ,[user_name]
	 ,[type_desc]
	  FROM #tempAccess) AS PivotDBUsers 
PIVOT (MAX(role_name) 
	   FOR [role_name] 
	   IN (db_owner
		  ,db_datareader
		  ,db_ssisadmin
		  ,SQLAgentOperatorRole
		  ,SQLAgentUserRole
		  ,SQLAgentReaderRole))piv;

INSERT INTO @tInstUsrRole
SELECT s.name AS  [user_name]
	  ,sp.type_desc
	  ,CASE dbcreator
		WHEN 1 THEN 'X'
		ELSE '-'
	   END CRE
	  ,CASE bulkadmin
		WHEN 1 THEN 'X'
		ELSE '-'
	   END [BULK]
FROM syslogins s
INNER JOIN sys.server_principals sp ON sp.name = s.name
WHERE s.name NOT LIKE '##%'
AND s.name NOT LIKE 'NT %'
AND s.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa') --Exclude default logins
--AND s.name IN ('PHX-DC\SRV_PHXDC-SAMSIT') --Search specific user
AND sp.type IN ('U','G','S')
ORDER BY s.name

DROP TABLE #tempAccess

--**--**--DISPLAY LOGINS WITH NON-STANDARD ACCESS--**--**--

SELECT @@SERVERNAME AS ServerName
	  ,i.[user_name] As LoginName
	  ,CASE
		WHEN d.OWN IS NULL THEN '-'
		ELSE d.OWN
	   END OWN
	  ,CASE 
		WHEN i.CRE IS NULL THEN '-'
		ELSE i.CRE
	   END CRE
	  ,CASE 
		WHEN i.[BULK] IS NULL THEN '-'
		ELSE i.[BULK]
	   END [BULK]
	  ,CASE
		WHEN d.[READ] IS NULL THEN '-'
		ELSE d.[READ]
	   END [READ]
	  ,CASE
		WHEN d.AGE IS NULL THEN '-'
		ELSE d.AGE
	   END AGE
	  ,CASE
		WHEN d.DTS IS NULL THEN '-'
		ELSE d.DTS
	   END DTS
	  ,i.[type_desc] AS LoginType
FROM @tInstUsrRole i
LEFT JOIN @tDbUsrRoles d ON d.[user_name] = i.[user_name] AND d.user_name IS NOT NULL
ORDER BY i.type_desc, i.[user_name]
GO