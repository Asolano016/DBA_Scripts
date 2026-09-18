USE [msdb]
GO

DECLARE @numDays INT,
	    @dbName VARCHAR(50),
		@bakType CHAR(1)

SET @numDays = 7; --Backup report range
SET @dbName  = '' --Filter by database name, if NULL or EMPTY will search for all database
SET @bakType = '' --Filter by backup type, if NULL or EMPTY will search for all backup types

SELECT s.[server_name] AS [ServerName]
	  ,s.[database_name] AS [DatabaseName]
	  ,s.[recovery_model] AS [RecoveryModel]
	  ,s.[compatibility_level] AS [CompatibilityLevel]
	  ,s.[collation_name] AS [CollationName]
	  ,CASE s.[type]
			WHEN 'D' THEN 'Database'
			WHEN 'I' THEN 'Differential database'
			WHEN 'L' THEN 'Log'
			WHEN 'F' THEN 'File or filegroup'
			WHEN 'G' THEN 'Differential file'
			WHEN 'P' THEN 'Partial'
			WHEN 'Q' THEN 'Differential partial'
			ELSE NULL
	   END AS [BackupType]
	  ,CASE mf.[device_type]
			WHEN 2 THEN 'Disk'
			WHEN 5 THEN 'Tape'
			WHEN 7 THEN 'Virtual Device'
			WHEN 9 THEN 'Azure Storage'
			WHEN 105 THEN 'A permanent backup device'
			ELSE NULL
	   END AS [DeviceType]
	  ,CASE s.[is_copy_only] WHEN 1 THEN 'Yes' ELSE 'No' END [IsCopyOnly]
	  ,s.[user_name] AS [LoginName]
	  ,mf.[physical_device_name] AS [PhysicalDeviceName]
	  ,((s.[backup_size]/1024)/1024) AS [BackupSizeMB]
	  --,((s.[compressed_backup_size]/1024)/1024) AS [CompressedBackupSizeMB]
	  --,CAST(100.0 * (1 - CAST(s.[compressed_backup_size] AS FLOAT) / NULLIF(s.[backup_size],0)) AS DECIMAL(10,2)) AS [CompressionSavingsPct]
	  ,CAST((s.backup_size / 1024.0 / 1024.0) / NULLIF(DATEDIFF(SECOND, s.backup_start_date, s.backup_finish_date), 0) AS decimal(18,2)) AS [BackupMBPerSecond]
	  ,DATEDIFF(SECOND, s.backup_start_date, s.backup_finish_date) AS [DurationSeconds]
	  ,DATEDIFF(MINUTE, s.backup_start_date, s.backup_finish_date) AS [DurationMinutes]
	  ,s.[backup_start_date] AS [StartDate]
	  ,s.[backup_finish_date] AS [FinishDate]
FROM msdb.dbo.backupset s 
INNER JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = s.media_set_id
WHERE s.[database_name] NOT IN ('master','msdb','model','Admin')
AND s.[backup_start_date] >= DATEADD(DAY,-@numDays,GETDATE())
AND (ISNULL(@dbName,'') = '' OR s.[database_name] = @dbName)
AND (ISNULL(@bakType,'') = '' OR s.[type] = @bakType)
--AND s.[user_name] <> 'NT AUTHORITY\SYSTEM'
ORDER BY s.[backup_start_date] DESC
GO