USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @query NVARCHAR(MAX),
	    @backupPath NVARCHAR(MAX),
		@excludeDatabases AS VARCHAR(255)

SET @backupPath = 'G:\backup\'
SET @excludeDatabases = "'tempdb','master','msdb','model','Admin'"

SELECT DatabaseName
	  ,CAST(((BackupSizeMB/1024)/1024) AS DECIMAL(10,2)) BackupSizeMB
	  --,CAST(((CompressedBackupSizeMB/1024)/1024) AS DECIMAL(10,2)) CompressedBackupSizeMB
	  INTO #tTempBackup
FROM
(SELECT d.name AS DatabaseName
	   ,b.backup_size AS BackupSizeMB
	   --,b.compressed_backup_size AS CompressedBackupSizeMB
	   ,ROW_NUMBER() OVER(PARTITION BY d.name ORDER BY b.backup_finish_date DESC) AS RN
FROM master.sys.databases d
INNER JOIN msdb.dbo.backupset b ON b.database_name = d.name
WHERE d.name NOT IN ('tempdb','master','msdb','model','Admin')
AND b.type = 'D') AS t
WHERE RN = 1

SET @query = "SELECT '--Backup Database ' + d.name  + ', Backup Size MB: ' + CAST(BackupSizeMB AS VARCHAR(50)) + ' 	   
BACKUP DATABASE ' + d.name + '
TO  DISK = N''" + @backupPath + "' + d.name + '_1.bak'',
    DISK = N''" + @backupPath + "' + d.name + '_2.bak'',
   DISK = N''" + @backupPath + "' + d.name + '_3.bak'',
   DISK = N''" + @backupPath + "' + d.name + '_4.bak''
WITH NAME = N''' + d.name + '-Full Database Backup'', COMPRESSION, COPY_ONLY, STATS = 10
GO
	   ' As BackupDatabases
FROM sys.databases d
INNER JOIN #tTempBackup t ON t.DatabaseName = d.[name]
WHERE d.name NOT IN (" + @excludeDatabases + ")
ORDER BY BackupSizeMB"

EXEC sp_executesql @query

DROP TABLE #tTempBackup	   