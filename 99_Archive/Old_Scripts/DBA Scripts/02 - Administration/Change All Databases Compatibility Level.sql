USE master
GO

SELECT 'ALTER DATABASE [' + name + '] SET COMPATIBILITY_LEVEL = 130;' 
FROM sys.databases
WHERE name NOT IN ('master','msdb','tempdb','model','Admin')
ORDER BY name
GO