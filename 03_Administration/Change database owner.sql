USE [master]
GO

DECLARE @CurrentOwner VARCHAR(100) = 'PHX-DC\admin-asolanoa'
DECLARE @NewOwner VARCHAR(100) = 'sa';

SELECT [name] AS 'DatabaseName',
	   SUSER_SNAME([owner_sid]) AS 'CurrentOwner',
	   'USE [' + [name] + ']; EXEC sp_changedbowner [' + @NewOwner + '];'  AS 'Script'
FROM sys.databases
WHERE [name] NOT IN ('Admin','master','msdb','model','tempdb')
--AND [name] = 'DBNAME' -- Just to update owner for one database
AND SUSER_SNAME([owner_sid]) = @CurrentOwner
ORDER BY [name]