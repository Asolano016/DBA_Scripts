--**--**--**--**--RESTORE BACKUP SCRIPTS--**--**--**--**--

USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#tFiles') IS NOT NULL
DROP TABLE #tFiles

DECLARE @bigDatabases AS VARCHAR(255),
	    @query NVARCHAR(MAX),
	    @backupPath NVARCHAR(MAX),
		@dataPath NVARCHAR(MAX),
		@logPath NVARCHAR(MAX)
SET @bigDatabases = "''" --Only for database base bigger than 30 GB
SET @backupPath = "PATH" --Backup path
SET @dataPath = "E:\SQLDBf_MSSQLSERVER\" --Data file location
SET @logPath = "F:\SQLLog_MSSQLSERVER\" --Log file location

CREATE TABLE #tFiles (
	id INT,
	name VARCHAR(50),
	data VARCHAR(50),
	log VARCHAR(50)
)

INSERT INTO #tFiles
SELECT d.database_id  
      ,d.name
      ,(SELECT TOP 1 md.name FROM sys.master_files md WHERE md.database_id = d.database_id AND md.type = 0) AS 'Data'
	  ,(SELECT TOP 1 md.name FROM sys.master_files md WHERE md.database_id = d.database_id AND md.type = 1) AS 'Log'
	 --,SUM(m.size * 8/1024) AS TotalSize
FROM sys.master_files m
INNER JOIN sys.databases d ON d.database_id = m.database_id
WHERE d.name NOT IN ('tempdb','master','msdb','model','Admin')
AND m.type = 0
ORDER BY d.name

/*
	--Restore Small Databases, One .bak File per Database
*/

SET @query = "SELECT '--Resore Database ' + d.name  + ', Total Size (MB): ' + CAST(SUM(m.size * 8/1024) AS VARCHAR(52)) + ' 	   		  	      
        
		RESTORE DATABASE ' + d.name + '
        FROM  DISK = N''" + @backupPath + "' + d.name + '.bak''
        WITH RECOVERY, REPLACE,
		MOVE '''+ d.data + ''' TO ''" + @dataPath + "' + d.data + '.mdf'',
		MOVE '''+ d.log + ''' TO ''" + @logPath + "' + d.log + '.ldf''
        GO
		' AS RestoreSmallDatabases
FROM sys.master_files m
INNER JOIN #tFiles d ON d.id = m.database_id
WHERE d.name NOT IN ('tempdb','master','msdb','model','Admin', " + @bigDatabases + ")
GROUP BY d.name, d.data, d.log
ORDER BY SUM(m.size * 8/1024)"

EXEC sp_executesql @query

/*
	--Restore Big Databases, One .bak File per Database
*/

SET @query = "SELECT '--Resore Database ' + d.name  + ', Total Size (MB): ' + CAST(SUM(m.size * 8/1024) AS VARCHAR(52)) + ' 	   		  	      
        
		RESTORE DATABASE ' + d.name + '
        FROM  DISK = N''" + @backupPath + "' + d.name + '_1.bak'',
			  DISK = N''" + @backupPath + "' + d.name + '_2.bak'',
			  DISK = N''" + @backupPath + "' + d.name + '_3.bak'',
			  DISK = N''" + @backupPath + "' + d.name + '_4.bak''
        WITH RECOVERY, REPLACE,
		MOVE '''+ d.data + ''' TO ''" + @dataPath + "' + d.data + '.mdf'',
		MOVE '''+ d.log + ''' TO ''" + @logPath + "' + d.log + '.ldf''
        GO
		' AS RestoreBigDatabases
FROM sys.master_files m
INNER JOIN #tFiles d ON d.id = m.database_id
WHERE d.name IN (" + @bigDatabases + ")
GROUP BY d.name, d.data, d.log
ORDER BY SUM(m.size * 8/1024)"

EXEC sp_executesql @query

IF OBJECT_ID('tempdb..#tFiles') IS NOT NULL
DROP TABLE #tFiles

