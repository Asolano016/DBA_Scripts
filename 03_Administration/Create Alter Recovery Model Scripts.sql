USE [master]
GO

--List of databases

SELECT @@SERVERNAME AS server_name, name, recovery_model_desc
FROM sys.databases
WHERE name NOT IN ('admin','master','msdb','model','tempdb')

--Scripts to alter databases recovery model
SELECT 'ALTER DATABASE [' + name  + '] SET RECOVERY SIMPLE;'
FROM sys.databases
WHERE name NOT IN ('admin','master','msdb','model','tempdb')