--**--**--**--**--BACKUP HISTORY--**--**--**--**--

USE msdb
GO

DECLARE @numDays INT,
	    @dbName VARCHAR(50),
		@bakType CHAR(1)

SET @numDays  = 7; --Backup report range
SET @dbName = '' --Filter by database name, if NULL or EMPTY will search for all database
SET @bakType = '' --Filter by backup type

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
	  ,s.[compatibility_level]
	  ,s.collation_name
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
	  ,((s.backup_size/1024)/1024) AS backup_size_mb
	  --,((s.compressed_backup_size/1024)/1024) AS compressed_backup_size_mb
	  ,DATEDIFF(MI, s.backup_start_date, s.backup_finish_date) time_taken_min
	  ,s.backup_start_date
	  ,s.backup_finish_date
FROM msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = s.media_set_id
WHERE (CONVERT(datetime, s.backup_start_date, 102) >= GETDATE() - @numDays) 
--AND s.database_name = @dbName OR COALESCE(@dbName, '') = ''
--AND s.database_name = 'DatabaseName'
--AND s.[type] = @bakType OR COALESCE(@bakType, '') = ''
ORDER BY s.backup_start_date DESC
GO