USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#tDatabasesList') IS NOT NULL
DROP TABLE #tDatabasesList;

CREATE TABLE #tDatabasesList(DatabaseName NVARCHAR(MAX));

DECLARE @query NVARCHAR(MAX),
	    @backupPath NVARCHAR(MAX),
		@exampleDB NVARCHAR(MAX),
		@dataPhysicalFilePath NVARCHAR(MAX),
		@logPhysicalFilePath NVARCHAR(MAX);

SELECT @dataPhysicalFilePath = REVERSE(SUBSTRING(REVERSE(mf.physical_name), CHARINDEX('\', REVERSE(mf.physical_name), 0), LEN(mf.physical_name))) -- AS 'PhysicalFilePath'
FROM sys.master_files mf
INNER JOIN sys.databases d ON d.database_id = mf.database_id
WHERE d.name NOT IN ('tempdb','master','msdb','model','Admin')
AND mf.type = 0
--WHERE d.name = @exampleDB
ORDER BY d.name

SELECT @logPhysicalFilePath = REVERSE(SUBSTRING(REVERSE(mf.physical_name), CHARINDEX('\', REVERSE(mf.physical_name), 0), LEN(mf.physical_name))) -- AS 'PhysicalFilePath'
FROM sys.master_files mf
INNER JOIN sys.databases d ON d.database_id = mf.database_id
WHERE d.name NOT IN ('tempdb','master','msdb','model','Admin')
AND mf.type = 1
--WHERE d.name = @exampleDB
ORDER BY d.name

SET @backupPath = '\\USQASWSTC000699\bk\'
--SET @exampleDB = 'FleetManager'

INSERT INTO #tDatabasesList
VALUES ('CA_API'),
	   ('CA_Dev'),
	   ('CA_LR_Core_DB'),
	   ('CA_LWMS_SIEMENS'),
	   ('CA_Print'),
	   ('CA_Stg_Locality_Registry')

SELECT "RESTORE DATABASE [" + DatabaseName + "] 
		FROM  DISK = N'" + @backupPath + DatabaseName + "_20220429.bak'
	    WITH  FILE = 1, MOVE N'" + DatabaseName + "' TO N'" + @dataPhysicalFilePath + DatabaseName + ".mdf',
						MOVE N'" + DatabaseName + "_log' TO N'" + @logPhysicalFilePath + DatabaseName + "_log.ldf',
		NOUNLOAD,  STATS = 5;"
FROM #tDatabasesList 


