--Check Total Database Size
USE master
GO

SELECT @@SERVERNAME AS InstanceName
	  ,DB_NAME(database_id) AS DatabaseName
	  --,SUM(CONVERT(BIGINT,size))*8/1024 AS SizeMB -- INT RESULT
	  ,CAST(SUM(mf.size) * 8.0 / 1024 AS DECIMAL(18,2)) AS SizeMB -- DECIMAL RESULT
	  --,(SUM(CONVERT(BIGINT,size))*8/1024)/1024 AS SizeGB -- INT RESULT
	  ,CAST(SUM(mf.size) * 8.0 / 1024 / 1024 AS DECIMAL(18,2)) AS SizeGB -- DECIMAL RESULT
FROM sys.master_files mf
WHERE DB_NAME(database_id) NOT IN ('Admin', 'master', 'tempdb', 'msdb', 'model') --Exclude system database
--AND DB_NAME(database_id) = 'DatabaseName' --Search for database name
GROUP BY database_id
ORDER BY SizeMB DESC