--**--**--**--**--CREATE BACKUP SCRIPTS--**--**--**--**--

USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @bigDatabases AS VARCHAR(254),
	    @excludeDatabases AS VARCHAR(254),
	    @query NVARCHAR(MAX),
	    @backupPath NVARCHAR(MAX)

SET @bigDatabases = "'DATABASENAME" --Only for database base bigger than 30 GB
SET @excludeDatabases= "'DATABASENAME'" --Exclude not necessary dataases
SET @backupPath = "PATH" --Add path where backup will be created

/*
	--Backup Small Databases, One .bak File per Database
*/

SET @query = "SELECT '--Backup Database ' + d.name  + ', Total Size (MB): ' + CAST(SUM(m.size * 8/1024) AS VARCHAR(52)) + ' 	   		  	      
        
		BACKUP DATABASE ' + d.name + '
        TO  DISK = N''" + @backupPath + "' + d.name + '.bak''
        WITH NOINIT,  NAME = N''' + d.name + '-Full Database Backup'', COMPRESSION,  STATS = 10, COPY_ONLY
        GO
		' AS BackupSmallDatabases
FROM sys.master_files m
INNER JOIN sys.databases d ON d.database_id = m.database_id
WHERE d.name NOT IN ('tempdb','master','msdb','model','Admin', " + @bigDatabases + ", " + @excludeDatabases + ")
GROUP BY d.name
ORDER BY SUM(m.size * 8/1024)"

--PRINT @query
EXEC sp_executesql @query

/*
	Backup Small Databases, Four .bak Files per Database
*/

SET @query = "SELECT '--Backup Database ' + d.name  + ', Total Size (MB): ' + CAST(SUM(m.size * 8/1024) AS VARCHAR(52)) + ' 
	   
	   BACKUP DATABASE ' + d.name + '
	   TO  DISK = N''" + @backupPath + "' + d.name + '_1.bak'',
	       DISK = N''" + @backupPath + "' + d.name + '_2.bak'',
		   DISK = N''" + @backupPath + "' + d.name + '_3.bak'',
		   DISK = N''" + @backupPath + "' + d.name + '_4.bak'',
	   WITH NOINIT,  NAME = N''' + d.name + '-Full Database Backup'', COMPRESSION,  STATS = 10, COPY_ONLY
	   GO
	   ' As BackupBigDatabases
FROM sys.master_files m
INNER JOIN sys.databases d ON d.database_id = m.database_id
WHERE d.name IN (" + @bigDatabases + ")
GROUP BY d.name
ORDER BY SUM(m.size * 8/1024)"

--PRINT @query
EXEC sp_executesql @query 
