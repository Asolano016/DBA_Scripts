USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @query NVARCHAR(MAX),
		@dbList NVARCHAR(MAX),
	    @backupPath NVARCHAR(MAX),
		@dataFilePath NVARCHAR(MAX),
		@logFilePath NVARCHAR(MAX),
		@excludeDatabases VARCHAR(MAX),
		@includeDatabases VARCHAR(MAX),
		@counter INT,
		@script VARCHAR(MAX);

DECLARE @tdbDataFile TABLE (
	db_name VARCHAR(100),   
	db_file VARCHAR(100)
) 

DECLARE @tdbLogFile TABLE (
	db_name VARCHAR(100),   
	db_file VARCHAR(100)
) 
DECLARE @tdbList TABLE(
dbId INT IDENTITY(1,1),
dbName VARCHAR(255)
)

DECLARE @tRestoreScript TABLE(
RestoreScript VARCHAR(MAX)
)

SET @backupPath = '\\mykulwstc000173.kul-dc.dhl.com\DBmigrationShared\RFC1696070-DontDelete\fullbackup-yellowgroup\'
SET @dataFilePath = 'E:\SQLDBf_APSALESMSSQL\'
SET @logFilePath = 'F:\SQLLog_APSALESMSSQL\'
SET @excludeDatabases = "'tempdb','master','msdb','model','Admin','rfMasterDESC','rfMasterDGF'"
SET @includeDatabases = "'T_Daily_Data'
,'T_LeadsToFTB'
,'T_APIC'
,'DS_CPI'
,'T_Program'
,'T_Customer_Development'
,'START'
,'DS_ReferenceTables'
,'T_Thailand'
,'DS_GSI'
,'T_CPI_DataSource'
,'T_NewZealand'
,'T_CREST'
,'DS_Main_Stream'
,'digitely'
,'digitely_test'
,'DP_LeadsBank'
,'T_Vietnam'
,'T_Tender'
,'T_Stickiness_Index'
,'SalesAnalysis'
,'AndrewWorking'
,'SPARKLE'
,'SalesFocusForum'"
SET @counter = 1

SET @script = "USE [?];

SELECT DB_NAME() AS 'db_name', name AS 'db_file'
FROM sysfiles
WHERE filename LIKE '%.mdf'"

INSERT INTO @tdbDataFile 
EXEC sp_MSForEachDB @script 

SET @script = "USE [?];

SELECT DB_NAME() AS 'db_name', name AS 'db_file'
FROM sysfiles
WHERE filename LIKE '%.ldf'"

INSERT INTO @tdbLogFile 
EXEC sp_MSForEachDB @script 

SET @dbList = "SELECT name
			   FROM sys.databases
			   --WHERE name NOT IN (" + @excludeDatabases + ")
			   WHERE name IN (" + @includeDatabases + ")"

INSERT INTO @tdbList
EXEC sp_executesql @dbList

--SELECT l.dbId
--	  ,l.dbName
--	  ,d.db_file AS 'dataFile'
--	  ,f.db_file AS 'logFile'
--FROM @tdbList  l
--INNER JOIN @tdbDataFile d ON l.dbName = d.db_name
--INNER JOIN @tdblogFile f ON l.dbName = f.db_name
--ORDER BY l.dbName

WHILE (SELECT COUNT(dbName) FROM @tdbList) >= @counter
BEGIN 

INSERT INTO @tRestoreScript
SELECT "RESTORE DATABASE [" + l.dbName + "]" + CHAR(13)+CHAR(10) +
	   "FROM  DISK = N'" + @backupPath + l.dbName + "_20220916_2326.bak'" + CHAR(13)+CHAR(10) +
	   "WITH  FILE = 1,  NOUNLOAD,  STATS = 10," + CHAR(13)+CHAR(10) +
	   "MOVE N'" + d.db_file + "' TO N'" + @dataFilePath + d.db_file + ".mdf'," + CHAR(13)+CHAR(10) +
	   "MOVE N'" + f.db_file + "' TO N'" + @logFilePath + f.db_file + ".ldf'" + CHAR(13)+CHAR(10) +
	   "GO" + CHAR(13)+CHAR(10) + CHAR(13)+CHAR(10) AS RestoreScript
FROM @tdbList l
INNER JOIN @tdbDataFile d ON l.dbName = d.db_name
INNER JOIN @tdblogFile f ON l.dbName = f.db_name
WHERE l.dbId = @counter

SET @counter = @counter + 1

END

SELECT RestoreScript 
FROM @tRestoreScript
