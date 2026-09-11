--User Check

USE master
GO

SELECT p.name
	  ,p.type_desc
	  ,l.sysadmin
	  ,l.securityadmin
	  ,l.processadmin
FROM sys.server_principals p
INNER JOIN syslogins l ON l.sid = p.sid
WHERE p.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa','PRG-DC\UDLDHL-SQLmigdist'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS'
				  ,'PAR_USERS')
AND p.name NOT LIKE '##%'
AND p.name NOT LIKE 'NT %'
AND p.type IN ('S','G','U')
ORDER BY p.name
GO
