/*
170 - SQL Server 2025 / Azure SQL
160 - SQL Server 2022
150 - SQL Server 2019
140 - SQL Server 2017
130 - SQL Server 2016
*/

USE [master]
GO

DECLARE @recoverModel VARCHAR(250)

SET @recoverModel = 'SIMPLE'

SELECT name AS 'DatabesName',
	   log_reuse_wait_desc AS 'LogReuseWait',
	   recovery_model_desc AS 'RecoveryModel',
	   'ALTER DATABASE [' + name + '] SET RECOVERY [' + @recoverModel + '];' AS 'Script'
FROM sys.databases
WHERE [recovery_model_desc] = 'FULL'
AND name NOT IN ('master','model','tempdb','msdb','admin')
--AND name = 'DBNAME' -- Just to update recovery model for one database
ORDER BY [name]