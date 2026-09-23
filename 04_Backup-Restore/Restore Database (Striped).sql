/******************************************************************************
GENERATE RESTORE DATABASE COMMANDS (STRIPED BACKUP)

PURPOSE

    Generate RESTORE DATABASE commands for one or multiple databases
    using striped backups.

FEATURES

    • Source and target database names can be different
    • WITH REPLACE support
    • WITH MOVE support
    • Multiple database support
    • Generates scripts only
    • Supports 4 striped backup files

******************************************************************************/

/******************************************************************************
HELPER

Use this if logical file names are unknown:

RESTORE FILELISTONLY
FROM DISK = N'\\BackupShare\MyBackup_1.bak';

******************************************************************************/

USE master;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER OFF;
GO

------------------------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------------------------

DECLARE @BackupPath NVARCHAR(4000);

DECLARE @UseReplace BIT;
DECLARE @UseMove BIT;

SET @BackupPath = N'\\BackupShare\';
SET @UseReplace = 0;
SET @UseMove    = 0;

------------------------------------------------------------------------------
-- DATABASE INVENTORY
------------------------------------------------------------------------------

DECLARE @tDatabases TABLE
(
    SourceDatabaseName SYSNAME,
    TargetDatabaseName SYSNAME,
    BackupFileName NVARCHAR(4000),
    DataLogicalName SYSNAME,
    LogLogicalName SYSNAME,
    DataFolder NVARCHAR(4000),
    LogFolder NVARCHAR(4000)
);

------------------------------------------------------------------------------
-- SAMPLE DATA
------------------------------------------------------------------------------

INSERT INTO @tDatabases (SourceDatabaseName, TargetDatabaseName, BackupFileName, DataLogicalName, LogLogicalName, DataFolder, LogFolder)
VALUES ('AndresTest', 'AndresTest', 'AndresTest_Backup', 'AndresTest', 'AndresTest_log', 'E:\SQLDBf_MSSQLSERVER\', 'F:\SQLLog_MSSQLSERVER\'),
       ('ResilienceTest', 'ResilienceTest', 'ResilienceTest_Backup', 'ResilienceTest', 'ResilienceTest_log', 'E:\SQLDBf_MSSQLSERVER\', 'F:\SQLLog_MSSQLSERVER\')

------------------------------------------------------------------------------
-- GENERATE RESTORE COMMANDS
------------------------------------------------------------------------------

SELECT

'/*============================================================
Target Database: '
+ TargetDatabaseName +
'
Backup Source: '
+ BackupFileName +
'
============================================================*/

RESTORE DATABASE ['

+ TargetDatabaseName +

']

FROM DISK = N'''

+ @BackupPath
+ BackupFileName
+ '_1.bak''

, DISK = N'''

+ @BackupPath
+ BackupFileName
+ '_2.bak''

, DISK = N'''

+ @BackupPath
+ BackupFileName
+ '_3.bak''

, DISK = N'''

+ @BackupPath
+ BackupFileName
+ '_4.bak''

WITH'

+ CASE
    WHEN @UseReplace = 1
        THEN ' REPLACE,'
    ELSE ''
  END

+ CASE
    WHEN @UseMove = 1
        THEN
'
 MOVE N'''
+ DataLogicalName
+ ''' TO N'''
+ DataFolder
+ TargetDatabaseName
+ '.mdf'',

 MOVE N'''
+ LogLogicalName
+ ''' TO N'''
+ LogFolder
+ TargetDatabaseName
+ '.ldf'','
    ELSE ''
  END

+ '
 RECOVERY,
 STATS = 10;

GO

' AS RestoreCommand
FROM @tDatabases
ORDER BY TargetDatabaseName;
GO