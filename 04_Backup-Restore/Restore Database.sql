/******************************************************************************
GENERATE RESTORE DATABASE COMMANDS
-------------------------------------------------------------------------------

PURPOSE

    Generate RESTORE DATABASE commands for one or multiple databases.

FEATURES

    • Single backup file support
    • 4-stripe backup support
    • WITH REPLACE support
    • WITH MOVE support
    • Multiple database support
    • Custom backup path
    • Custom data/log folders

NOTES

    This script only GENERATES restore commands.

    It does NOT execute restores.

******************************************************************************/

USE master;
GO

------------------------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------------------------

DECLARE @BackupPath NVARCHAR(4000);

DECLARE @UseStripes BIT;
DECLARE @UseReplace BIT;
DECLARE @UseMove BIT;

SET @BackupPath = N'\\BackupShare\';

SET @UseStripes = 0;
SET @UseReplace = 0;
SET @UseMove = 0;

------------------------------------------------------------------------------
-- DATABASE LIST
--
-- Logical names only required when @UseMove = 1
------------------------------------------------------------------------------

DECLARE @tDatabases TABLE
(
    DatabaseName      SYSNAME,
    DataLogicalName   SYSNAME,
    LogLogicalName    SYSNAME,
    DataFolder        NVARCHAR(4000),
    LogFolder         NVARCHAR(4000)
);

INSERT INTO @tDatabases (DatabaseName, DataLogicalName, LogLogicalName, DataFolder, LogFolder)
VALUES('ERP','ERP_Data','ERP_Log','E:\SQLData\','F:\SQLLogs\'),
      ('CRM','CRM_Data','CRM_Log','E:\SQLData\','F:\SQLLogs\');

------------------------------------------------------------------------------
-- GENERATE RESTORE COMMANDS
------------------------------------------------------------------------------

SELECT

'--==============================================================
-- Database: ' + d.DatabaseName + '
--==============================================================

'

+

CASE

------------------------------------------------------------------------------
-- SINGLE BACKUP FILE
------------------------------------------------------------------------------

WHEN @UseStripes = 0 THEN

'RESTORE DATABASE [' + d.DatabaseName + ']
FROM DISK = N'''
+
@BackupPath
+
d.DatabaseName
+
'_FULL.bak''
'

------------------------------------------------------------------------------
-- 4 STRIPES
------------------------------------------------------------------------------

ELSE

'RESTORE DATABASE [' + d.DatabaseName + ']
FROM DISK = N'''
+
@BackupPath
+
d.DatabaseName
+
'_FULL_1.bak''

, DISK = N'''
+
@BackupPath
+
d.DatabaseName
+
'_FULL_2.bak''

, DISK = N'''
+
@BackupPath
+
d.DatabaseName
+
'_FULL_3.bak''

, DISK = N'''
+
@BackupPath
+
d.DatabaseName
+
'_FULL_4.bak''
'

END

+

'
WITH
'

+

CASE

    WHEN @UseReplace = 1
        THEN CHAR(13) + CHAR(10) + '      REPLACE'
    ELSE ''

END

+

CASE

------------------------------------------------------------------------------
-- MOVE FILES
------------------------------------------------------------------------------

    WHEN @UseMove = 1
    THEN

CHAR(13) + CHAR(10) +

'    , MOVE N'''
+
d.DataLogicalName
+
''' TO N'''
+
d.DataFolder
+
d.DatabaseName
+
'.mdf'''

+

CHAR(13) + CHAR(10) +

'    , MOVE N'''
+
d.LogLogicalName
+
''' TO N'''
+
d.LogFolder
+
d.DatabaseName
+
'.ldf'''

    ELSE ''

END

+

'
    , RECOVERY
    , STATS = 10;

GO
'

AS RestoreCommand

FROM @tDatabases d

ORDER BY d.DatabaseName;

GO

/******************************************************************************
OPTIONAL HELPERS
******************************************************************************/

PRINT 'Run RESTORE FILELISTONLY first if logical file names are unknown.';
PRINT '';

PRINT 'Example:';

PRINT '
RESTORE FILELISTONLY
FROM DISK = N''\\BackupShare\ERP_FULL.bak'';
';

GO