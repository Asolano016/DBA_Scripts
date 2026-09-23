USE msdb
GO

DECLARE @dbName VARCHAR(50)

SET @dbName = '' --Filter by database name, if NULL or EMPTY will search for all database

SELECT @@SERVERNAME AS server_name 
	  ,h.destination_database_name
      ,h.[user_name]
	  ,CASE h.restore_type
		WHEN 'D' THEN 'Database'
		WHEN 'F' THEN 'File'
		WHEN 'G' THEN 'Filegroup'
		WHEN 'I' THEN 'Differential'
		WHEN 'L' THEN 'Log'
		WHEN 'V' THEN 'Verifyinly'
	    ELSE NULL
	   END restore_type
	  ,h.stop_at
	  --,f.destination_phys_name
	  ,h.restore_date
FROM msdb.dbo.restorehistory h
--INNER JOIN msdb.dbo.restorefile f ON f.restore_history_id = h.restore_history_id
WHERE h.destination_database_name = @dbName OR COALESCE(@dbName, '') = ''
ORDER BY h.restore_date DESC, h.destination_database_name
GO
