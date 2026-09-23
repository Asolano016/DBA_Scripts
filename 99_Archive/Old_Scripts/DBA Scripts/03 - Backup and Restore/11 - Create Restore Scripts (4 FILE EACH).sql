USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @query NVARCHAR(MAX),
		@dbList NVARCHAR(MAX),
	    @backupPath NVARCHAR(MAX),
		@excludeDatabases VARCHAR(MAX),
		@includeDatabases VARCHAR(MAX),
		@counter INT

DECLARE @tdbList TABLE(
dbId INT IDENTITY(1,1),
dbName VARCHAR(255)
)

DECLARE @tRestoreScript TABLE(
RestoreScript VARCHAR(MAX)
)

SET @backupPath = '\\Prg-dc.dhl.com\czcho\BS28823\CWTMS_DBbackup_PROD\AuditMigration-Backup\'
SET @excludeDatabases = "'tempdb','master','msdb','model','Admin','AlwaysOnTestDB','AlwaysOnTestDB2','AlwaysOnTestDB2Restore','AlwaysOnTestDB2restore2','TESTFRP_Audit'"
SET @includeDatabases = "'CargowiseoneDFOBNJPRO_Audit','CWTMS','CargowiseoneDFOBNJPRO'"
SET @counter = 1

SET @dbList = "SELECT name
			   FROM sys.databases
			   WHERE name NOT IN (" + @excludeDatabases + ")
			   --WHERE name IN (" + @includeDatabases + ")"

PRINT @dbList

INSERT INTO @tdbList
VALUES ('CargowiseoneDFOBNJPRO_Audit'),
	   ('CWTMS'),
	   ('CargowiseoneDFOBNJPRO')
--EXEC sp_executesql @dbList

WHILE (SELECT COUNT(dbName) FROM @tdbList) >= @counter
BEGIN 

INSERT INTO @tRestoreScript
SELECT "ALTER DATABASE [" +dbName + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE" + CHAR(13)+CHAR(10) +
	   "RESTORE DATABASE [" + dbName + "]" + CHAR(13)+CHAR(10) +
	   "FROM  DISK = N'" + @backupPath + "\" + dbName + "_1.bak'," + CHAR(13)+CHAR(10) +
	   "	  DISK = N'" + @backupPath + "\" + dbName + "_2.bak'," + CHAR(13)+CHAR(10) +
	   "	  DISK = N'" + @backupPath + "\" + dbName + "_3.bak'," + CHAR(13)+CHAR(10) +
	   "	  DISK = N'" + @backupPath + "\" + dbName + "_4.bak'" + CHAR(13)+CHAR(10) +
	   "WITH  FILE = 1,  NOUNLOAD,  REPLACE,  STATS = 10" + CHAR(13)+CHAR(10) +
	   "ALTER DATABASE [" + dbName + "] SET MULTI_USER" + CHAR(13)+CHAR(10) +
	   "GO" + CHAR(13)+CHAR(10) + CHAR(13)+CHAR(10) AS RestoreScript
FROM @tdbList 
WHERE dbId = @counter

SET @counter = @counter + 1

END

SELECT RestoreScript 
FROM @tRestoreScript
