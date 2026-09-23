--**--**--**--**--BACKUP HISTORY--**--**--**--**--

USE msdb
GO

SELECT s.server_name
	  ,s.database_name
	  ,CASE s.[type]
		WHEN 'D' THEN 'Database'
		WHEN 'I' THEN 'Differential database'
		WHEN 'L' THEN 'Log'
		WHEN 'F' THEN 'File or filegroup'
		WHEN 'G' THEN 'Differential file'
		WHEN 'P' THEN 'Partial'
		WHEN 'Q' THEN 'Differential partial'
		ELSE NULL
	   END [type]
	  ,s.recovery_model
	  ,CASE s.is_copy_only
		WHEN 1 THEN 'Yes'
		ELSE 'No'
	   END is_copy_only
	  ,CASE mf.device_type
		WHEN 2 THEN 'Disk'
		WHEN 5 THEN 'Tape'
		WHEN 7 THEN 'Virtual Device'
		WHEN 9 THEN 'Azure Storage'
		WHEN 105 THEN 'A permanent backup device'
		ELSE NULL
	   END device_type
	   ,s.user_name
	   ,mf.physical_device_name
	  ,s.backup_start_date
	  ,s.backup_finish_date
FROM msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = s.media_set_id
--WHERE (CONVERT(datetime, s.backup_start_date, 102) >= GETDATE() - 60) 
--AND s.database_name = @dbName OR COALESCE(@dbName, '') = ''
--AND s.database_name = 'DatabaseName'
--AND s.[type] = @bakType OR COALESCE(@bakType, '') = ''
ORDER BY s.backup_start_date DESC
GO