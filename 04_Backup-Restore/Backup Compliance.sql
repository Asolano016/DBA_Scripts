USE [msdb]
GO

;WITH LastFullBackup AS
(
    SELECT database_name
	      ,MAX(backup_finish_date) AS LastFullBackup
    FROM msdb.dbo.backupset
    WHERE type = 'D'
    GROUP BY database_name
)
SELECT d.[name] AS [DatabaseName]
	  ,l.[LastFullBackup]
	  ,DATEDIFF(HOUR, l.[LastFullBackup], GETDATE()) AS [HoursSinceBackup]
FROM sys.databases d
LEFT JOIN LastFullBackup l ON d.[name] = l.[database_name]
WHERE d.[name] NOT IN ('master','model','msdb','tempdb','Admin')
ORDER BY HoursSinceBackup DESC;