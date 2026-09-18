USE [msdb]
GO

;WITH LastBackup AS
(
    SELECT database_name
		  ,type
		  ,backup_finish_date
		  ,ROW_NUMBER() OVER( PARTITION BY database_name, type ORDER BY backup_finish_date DESC) AS RN
    FROM msdb.dbo.backupset
)
SELECT [database_name] AS [DatabaseName]
	  ,CASE [type]
			WHEN 'D' THEN 'Database'
			WHEN 'I' THEN 'Differential database'
			WHEN 'L' THEN 'Log'
			WHEN 'F' THEN 'File or filegroup'
			WHEN 'G' THEN 'Differential file'
			WHEN 'P' THEN 'Partial'
			WHEN 'Q' THEN 'Differential partial'
			ELSE NULL
	    END AS [BackupType]
	   ,[backup_finish_date] AS [BackupFinishDate]
	   ,DATEDIFF(HOUR, [backup_finish_date], GETDATE()) AS [BackupAgeHours]
FROM [LastBackup]
WHERE [RN] = 1
ORDER BY [database_name]