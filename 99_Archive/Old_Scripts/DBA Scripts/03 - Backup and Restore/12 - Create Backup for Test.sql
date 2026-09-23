USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @query NVARCHAR(MAX),
	    @backupPath NVARCHAR(MAX),
		@excludeDatabases AS VARCHAR(255)

SET @backupPath = '\\USQASWSTC000699\bk\'
SET @excludeDatabases = "'tempdb','master','msdb','model','Admin'"

SET @query = "SELECT '--Backup Database ' + d.name  + '   
BACKUP DATABASE ' + d.name + '
TO  DISK = N''" + @backupPath + "' + d.name + '_1.bak,''
    DISK = N''" + @backupPath + "' + d.name + '_2.bak,''
   DISK = N''" + @backupPath + "' + d.name + '_3.bak,''
   DISK = N''" + @backupPath + "' + d.name + '_4.bak''
WITH NAME = N''' + d.name + '-Full Database Backup'', COMPRESSION, COPY_ONLY, STATS = 10
GO' As BackupDatabases
FROM sys.databases d
WHERE d.name IN (" + @excludeDatabases + ")
ORDER BY d.name"

EXEC sp_executesql @query