USE [master]
GO

--ATTACH

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @script VARCHAR(MAX);

DECLARE @tdbDataFile TABLE (
	dbName VARCHAR(100),   
	dbLogicalFile VARCHAR(MAX),
	dbPhysichalFile VARCHAR(MAX)
) 

DECLARE @tdbLogFile TABLE (
	dbName VARCHAR(100),   
	dbLogicalFile VARCHAR(MAX),
	dbPhysichalFile VARCHAR(MAX)
) 

SET @script = "USE [?];

SELECT DB_NAME() AS 'dbName', name AS 'dbLogicalFile', filename AS 'dbPhysichalFile'
FROM sysfiles
WHERE filename LIKE '%.mdf'"

INSERT INTO @tdbDataFile 
EXEC sp_MSForEachDB @script 

SET @script = "USE [?];

SELECT DB_NAME() AS 'dbName', name AS 'dbLogicalFile', filename AS 'dbPhysichalFile'
FROM sysfiles
WHERE filename LIKE '%.ldf'"

INSERT INTO @tdbLogFile 
EXEC sp_MSForEachDB @script 

/*
SELECT d.name AS 'dbName'
	  ,df.dbPhysichalFile
	  ,lf.dbPhysichalFile
FROM sys.databases d
INNER JOIN @tdbDataFile df ON df.dbName = d.name
INNER JOIN @tdblogFile lf ON lf.dbName = d.name
ORDER BY d.name
*/

SELECT "CREATE DATABASE [" + d.name + "]" + CHAR(13)+CHAR(10) +
	   "ON (FILENAME = '" + df.dbPhysichalFile + "'),"  + CHAR(13)+CHAR(10) +
	   "   (FILENAME = '" +lf.dbPhysichalFile + "')"  + CHAR(13)+CHAR(10) +
	   "FOR ATTACH;" AS 'Script'
FROM sys.databases d
INNER JOIN @tdbDataFile df ON df.dbName = d.name
INNER JOIN @tdblogFile lf ON lf.dbName = d.name
WHERE d.database_id NOT BETWEEN 1 AND 5
ORDER BY d.name
