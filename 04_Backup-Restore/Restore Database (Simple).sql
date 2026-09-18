/******************************************************************************
GENERATE RESTORE DATABASE COMMANDS (SINGLE BACKUP FILE)

PURPOSE

    Generate RESTORE DATABASE commands for one or multiple databases
    using a single .bak file.

FEATURES

    • Source and target database names can be different
    • WITH REPLACE support
    • WITH MOVE support
    • Multiple database support
    • Generates scripts only

******************************************************************************/

USE master;
GO

SET NOCOUNT ON;

------------------------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------------------------

DECLARE @BackupPath NVARCHAR(4000);

DECLARE @UseReplace BIT;
DECLARE @UseMove BIT;

SET @BackupPath = N'\\BackupShare\';

SET @UseReplace = 1;
SET @UseMove    = 1;

------------------------------------------------------------------------------
-- DATABASE INVENTORY
------------------------------------------------------------------------------

DECLARE @Databases TABLE
(
      SourceDatabaseName SYSNAME
    , TargetDatabaseName SYSNAME

    , BackupFileName NVARCHAR(4000)

    , DataLogicalName SYSNAME
    , LogLogicalName SYSNAME

    , DataFolder NVARCHAR(4000)
    , LogFolder NVARCHAR(4000)
);

------------------------------------------------------------------------------
-- SAMPLE DATA
------------------------------------------------------------------------------

INSERT INTO @Databases
(
      SourceDatabaseName
    , TargetDatabaseName
    , BackupFileName
    , DataLogicalName
    , LogLogicalName
    , DataFolder
    , LogFolder
)
VALUES

(
      'ERP'
    , 'ERP_UAT'
    , 'ERP_FULL'
    , 'ERP_Data'
    , 'ERP_Log'
    , 'E:\SQLData\'
    , 'F:\SQLLogs\'
),

(
      'CRM'
    , 'CRM_DEV'
    , 'CRM_Data'
    , 'CRM_Log'
    , 'E:\SQLData\'
    , 'F:\SQLLogs\'
);

------------------------------------------------------------------------------
-- GENERATE RESTORE COMMANDS
------------------------------------------------------------------------------

SELECT

'
/*============================================================
Target Database ....: ' + TargetDatabaseName + '
Backup Source ......: ' + BackupFileName + '
============================================================*/

RESTORE DATABASE [' + TargetDatabaseName + ']

FROM DISK = N'''
+ @BackupPath
+ BackupFileName
+ '.bak''

WITH'

+ CASE
    WHEN @UseReplace = 1
        THEN '
      REPLACE'
    ELSE ''
  END

+ CASE

    WHEN @UseMove = 1

    THEN

'
    , MOVE N''' + DataLogicalName + '''
        TO N''' + DataFolder + TargetDatabaseName + '.mdf''

    , MOVE N''' + LogLogicalName + '''
        TO N''' + LogFolder + TargetDatabaseName + '.ldf'''
'

    ELSE ''

  END

+ '
    , RECOVERY
    , STATS = 10;

GO
'

AS RestoreCommand

FROM @Databases

ORDER BY TargetDatabaseName;

GO

/******************************************************************************
HELPER

Use this if logical file names are unknown:

RESTORE FILELISTONLY
FROM DISK = N''\\BackupShare\MyBackup.bak'';

******************************************************************************/