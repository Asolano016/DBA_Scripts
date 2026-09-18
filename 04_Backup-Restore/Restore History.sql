USE msdb
GO

DECLARE @dbName VARCHAR(50)

SET @dbName = '' --Filter by database name, if NULL or EMPTY will search for all database

SELECT h.[restore_history_id]
	  ,h.[destination_database_name] AS [DatabaseName]
      ,h.[user_name]
	  ,CASE h.[restore_type]
		WHEN 'D' THEN 'Database'
		WHEN 'F' THEN 'File'
		WHEN 'G' THEN 'Filegroup'
		WHEN 'I' THEN 'Differential'
		WHEN 'L' THEN 'Log'
		WHEN 'V' THEN 'VerifyOnly'
	    ELSE NULL
	   END [RestoreType]
	  ,h.stop_at AS [StopAt]
	  --,f.destination_phys_name AS [DestinationPhysName]
	  ,DATEDIFF(HOUR,h.[restore_date], GETDATE()) AS HoursSinceRestore
	  ,DATEDIFF(DAY, h.[restore_date], GETDATE()) AS DaysSinceRestore
	  ,h.[restore_date]
FROM msdb.dbo.restorehistory h
--INNER JOIN msdb.dbo.restorefile f ON f.restore_history_id = h.restore_history_id
WHERE (ISNULL(@dbName,'') = '' OR h.[destination_database_name] = @dbName)
ORDER BY h.restore_date DESC, h.destination_database_name
GO
