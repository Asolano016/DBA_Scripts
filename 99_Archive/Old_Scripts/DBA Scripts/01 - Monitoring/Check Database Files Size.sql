--'--Check Each Database File Size

USE master
GO

SELECT @@SERVERNAME AS InstanceName
	  ,DB_NAME(database_id) AS DatabaseName
	  ,name AS LogicalName
	  ,REVERSE(SUBSTRING(REVERSE(physical_name), 0, CHARINDEX('\',REVERSE(physical_name)))) AS PhysicalName
	  ,REVERSE(SUBSTRING(REVERSE(physical_name), CHARINDEX('\', REVERSE(physical_name)) + 1, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)))) + '\' AS FilesPath
	  ,(CONVERT(BIGINT,size)*8)/1024 As SizeMB
	  ,(CONVERT(BIGINT,size)*8)/1024/1024 As SizeGB
FROM sys.master_files
WHERE DB_NAME(database_id) NOT IN ('Admin', 'master', 'tempdb', 'msdb', 'model') --Exclude system databases
--AND DB_NAME(database_id) = 'DatabaseName' --Search for database name
--AND type = 0 --Search for data files
--AND type = 1 --Search for log files
ORDER BY SizeMB DESC


--'--Check Total Database Size

USE master
GO

SELECT @@SERVERNAME AS InstanceName
	  ,DB_NAME(database_id) AS DatabaseName
	  ,SUM(CONVERT(BIGINT,size))*8/1024 AS DbTotalSizeMB
	  ,(SUM(CONVERT(BIGINT,size))*8/1024)/1024 AS DbTotalSizeGB
FROM sys.master_files
WHERE DB_NAME(database_id) NOT IN ('Admin', 'master', 'tempdb', 'msdb', 'model') --Exclude system database
--AND DB_NAME(database_id) = 'DatabaseName' --Search for database name
GROUP BY database_id
ORDER BY DbTotalSizeMB DESC