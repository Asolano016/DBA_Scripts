SELECT name AS DBNAME
	  ,SUSER_SNAME(owner_sid) AS DBOWNER
	  ,'USE [' + name + ']; EXEC sp_changedbowner [sa];'  AS 'ChangeOwner'
FROM sys.databases
WHERE name NOT IN ('Admin','master','msdb','model','tempdb')
AND SUSER_SNAME(owner_sid) = 'LOGINNAME'