/*Script - Restore History*/
SELECT DISTINCT rh.destination_database_name AS 'DatabaseName'
      ,rh.user_name AS 'LoginName'
	  ,CASE rh.restore_type
		WHEN 'D' THEN 'Database'
		WHEN 'F' THEN 'File'
		WHEN 'G' THEN 'Filegroup'
		WHEN 'I' THEN 'Differential'
		WHEN 'L' THEN 'Log'
		WHEN 'V' THEN 'Verifyinly'
	    ELSE NULL
	   END AS 'RestoreType'
	  ,CASE rh.replace
		WHEN 1 THEN 'Yes'
		ELSE 'No'
	   END 'Replace'
	  ,CASE rh.recovery
		WHEN 1 THEN 'Yes'
		ELSE 'No'
	   END 'Recovery'
	   ,bmf.physical_device_name as BackupFileLocation
	  ,(SELECT rf.destination_phys_name FROM msdb..restorefile rf WHERE rf.restore_history_id = rh.restore_history_id AND rf.file_number = 1) AS 'DestinationDataFile'
	  ,(SELECT rf.destination_phys_name FROM msdb..restorefile rf WHERE rf.restore_history_id = rh.restore_history_id AND rf.file_number = 2) AS 'DestinationLogFile'
	  ,rh.restore_date AS 'RestoreDate'
FROM msdb.dbo.restorehistory rh
INNER JOIN msdb..backupset bs ON rh.backup_set_id = bs.backup_set_id
INNER JOIN msdb..backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id 
WHERE rh.restore_date >= GETDATE() - 30
ORDER BY rh.restore_date DESC, rh.destination_database_name;