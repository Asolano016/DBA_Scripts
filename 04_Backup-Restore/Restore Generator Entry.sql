/******************************************************************************
DATABASE FILE INVENTORY
-------------------------------------------------------------------------------

PURPOSE

    Generate the information required by the
    Restore Generate Scripts.sql utility.

OUTPUT

    DatabaseName
    DataLogicalName
    LogLogicalName
    DataFolder
    LogFolder

******************************************************************************/

SET QUOTED_IDENTIFIER OFF
GO

WITH DataFiles AS
(
    SELECT d.name AS DatabaseName
		  ,mf.name AS DataLogicalName
		  ,LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name))) + '\' AS DataFolder
    FROM sys.databases d
    INNER JOIN sys.master_files mf ON d.database_id = mf.database_id
    WHERE mf.type = 0
),
LogFiles AS
(
    SELECT d.name AS DatabaseName
		 , mf.name AS LogLogicalName
		 ,LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name))) + '\' AS LogFolder
    FROM sys.databases d
    INNER JOIN sys.master_files mf ON d.database_id = mf.database_id
    WHERE mf.type = 1
)

SELECT d.DatabaseName
	  ,d.DataLogicalName
	  ,l.LogLogicalName
	  ,d.DataFolder
	  ,l.LogFolder
	  ,"('" + d.DatabaseName + "', '" + d.DataLogicalName + "', '" + l.LogLogicalName + "', '" + d.DataFolder + "', '" + l.LogFolder + "'),'" AS RestoreGeneratorEntry
FROM DataFiles d
INNER JOIN LogFiles l ON d.DatabaseName = l.DatabaseName
WHERE d.DatabaseName NOT IN
('master','model','msdb','tempdb','Admin')