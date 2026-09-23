--NON-STANDARD

/*
DESCRIPTION: Check logins in the instance that could has non-standard access in relation of the PAR system
*/

USE master
GO

--**--**--DECLARE VARIABLE TABLES--**--**--

DECLARE @tALTT TABLE(
	[user_name] NVARCHAR(100),
	ALTT CHAR(2)
)

DECLARE @tACMO TABLE(
	[user_name] NVARCHAR(100),
	ACMO CHAR(2)
)

DECLARE @tALTT_ACMO TABLE(
	[user_name] NVARCHAR(100),
	ALTT CHAR(2),
	ACMO CHAR(2) 
)

DECLARE @tSYSA TABLE(
	[user_name] NVARCHAR(100),
	SYSA CHAR(2),
	SECA CHAR(2),
	PRCA CHAR(2),
	type_desc VARCHAR(25)
)

--**--**--INSERT LOGINS WITH ALTER TRACE--**--**--

INSERT INTO @tALTT
SELECT sp.name AS [user_name]
	  ,CASE 
		WHEN p.permission_name = 'ALTER TRACE' THEN 'X'
		ELSE '-'
	   END ALTT
FROM sys.server_principals sp
INNER JOIN sys.server_permissions p ON p.grantee_principal_id = sp.principal_id AND p.permission_name IN ('ALTER TRACE')
WHERE sp.name NOT LIKE '##%'
AND sp.name NOT LIKE 'NT %'
AND sp.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa')
AND sp.type IN ('U','G','S')
ORDER BY sp.type_desc, sp.name

--**--**--INSERT LOGINS WITH ACTIVITY MONITOR--**--**--
INSERT INTO @tACMO
SELECT sp.name AS [user_name]
	  ,CASE 
		WHEN p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DATABASE') THEN 'X'
		ELSE '-'
	   END ACMO
FROM sys.server_principals sp
INNER JOIN sys.server_permissions p ON p.grantee_principal_id = sp.principal_id AND p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DATABASE')
WHERE sp.name NOT LIKE '##%'
AND sp.name NOT LIKE 'NT %'
AND sp.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa')
AND sp.type IN ('U','G','S')
GROUP BY sp.name,sp.type_desc, CASE 
								 WHEN p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DATABASE') THEN 'X'
								 ELSE '-'
								END

--**--**--INSERT RESULTS BETWEEN ACMO AND ALTT--**--**--
INSERT INTO @tALTT_ACMO
SELECT t.user_name
	  ,CASE 
		WHEN t.ALTT IS NULL THEN '-'
		ELSE t.ALTT
	   END ALTT
	  ,CASE 
		WHEN m.ACMO IS NULL THEN '-'
		ELSE m.ACMO
	   END ACMO
FROM @tALTT t
LEFT JOIN @tACMO m ON m.user_name = t.user_name AND m.user_name IS NOT NULL

UNION

SELECT m.user_name
	  ,CASE 
		WHEN t.ALTT IS NULL THEN '-'
		ELSE t.ALTT
	   END ALTT
	  ,CASE 
		WHEN m.ACMO IS NULL THEN '-'
		ELSE m.ACMO
	   END ACMO
FROM @tALTT t
RIGHT JOIN @tACMO m ON m.user_name = t.user_name AND t.user_name IS NOT NULL

--**--**--INSERT RESULT FOR SYSA, SECA AND PRCA
INSERT INTO @tSYSA
SELECT sp.name
	  ,CASE s.sysadmin
		WHEN 1 THEN 'X'
		ELSE '-'
	   END SYSA
	  ,CASE s.securityadmin
		WHEN 1 THEN 'X'
		ELSE '-'
	   END SECA
	  ,CASE s.processadmin
		WHEN 1 THEN 'X'
		ELSE '-'
	   END PRCA
	  ,sp.type_desc
FROM syslogins s
INNER JOIN sys.server_principals sp ON sp.name = s.name
WHERE s.name NOT LIKE '##%'
AND s.name NOT LIKE 'NT %'
AND s.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa')
AND sp.type IN ('U','G','S')
ORDER BY s.name

--**--**--DISPLAY LOGINS WITH NON-STANDARD ACCESS--**--**--

SELECT @@SERVERNAME AS ServerName
	  ,s.user_name
      ,s.SYSA
	  ,s.SECA
	  ,s.PRCA
	  ,CASE
		WHEN a.ALTT IS NULL THEN '-'
		ELSE a.ALTT
	   END ALTT
	  ,CASE
		WHEN a.ACMO IS NULL THEN '-'
		ELSE a.ACMO
	   END ACMO
	  ,s.type_desc As LoginType
FROM @tSYSA s
LEFT JOIN @tALTT_ACMO a ON a.user_name = s.user_name
ORDER BY s.type_desc, s.user_name
GO