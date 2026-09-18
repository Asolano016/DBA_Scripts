USE master
GO

DECLARE @CompatibilityLevel CHAR(3) = '130'

SELECT [name] AS 'DatabaseName',
	   'ALTER DATABASE [' + [name] + '] SET COMPATIBILITY_LEVEL = ' + @CompatibilityLevel + ';' AS 'Script'
FROM sys.databases
WHERE [name] NOT IN ('master','msdb','tempdb','model','Admin')
--AND [name] = 'DBNAME' -- Just to update compatibility level for one database
ORDER BY [name]
GO