/******************************************************************************
BACKUP CHAIN BUILDER
-------------------------------------------------------------------------------

PURPOSE

    Identify the backups required to perform a restore operation
    up to a specific point in time.

OUTPUT

    • RestoreSequence
    • BackupType
    • BackupFinishDate
    • PhysicalDeviceName
    • FirstLSN
    • LastLSN

NOTES

    This script DOES NOT generate RESTORE commands.

    It identifies the required backup chain.

******************************************************************************/

USE msdb;
GO

------------------------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------------------------

DECLARE @DatabaseName SYSNAME;
DECLARE @RestoreToDate DATETIME;

SET @DatabaseName = 'SQLInventory';

-- Target restore point
SET @RestoreToDate = GETDATE(); --'2026-09-18 20:07:33.000'

------------------------------------------------------------------------------
-- STEP 1
-- FIND LATEST FULL BACKUP BEFORE TARGET DATE
------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Chain') IS NOT NULL
    DROP TABLE #Chain;

CREATE TABLE #Chain
(
    RestoreSequence INT,
    BackupType VARCHAR(20),
    BackupStartDate DATETIME,
    BackupFinishDate DATETIME,
    FirstLSN NUMERIC(25,0),
    LastLSN NUMERIC(25,0),
    DatabaseBackupLSN NUMERIC(25,0),
    PhysicalDeviceName NVARCHAR(4000),
);

DECLARE @FullBackupDate DATETIME;
DECLARE @FullDatabaseBackupLSN NUMERIC(25,0);

SELECT TOP (1) @FullBackupDate = bs.backup_finish_date
      ,@FullDatabaseBackupLSN = bs.checkpoint_lsn
FROM msdb.dbo.backupset bs
WHERE bs.database_name = @DatabaseName
AND bs.type = 'D'
AND bs.backup_finish_date <= @RestoreToDate
ORDER BY bs.backup_finish_date DESC;

------------------------------------------------------------------------------
-- STEP 2
-- INSERT BASE FULL BACKUP
------------------------------------------------------------------------------

INSERT INTO #Chain
SELECT 1
      ,'FULL'
      ,bs.backup_start_date
      ,bs.backup_finish_date
      ,bs.first_lsn
      ,bs.last_lsn
      ,bs.database_backup_lsn
      ,bmf.physical_device_name
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = @DatabaseName
AND bs.type = 'D'
AND bs.backup_finish_date = @FullBackupDate;

------------------------------------------------------------------------------
-- STEP 3
-- FIND LATEST DIFFERENTIAL BACKUP
------------------------------------------------------------------------------

DECLARE @DiffBackupDate DATETIME;

SELECT TOP (1) @DiffBackupDate = bs.backup_finish_date
FROM msdb.dbo.backupset bs
WHERE bs.database_name = @DatabaseName
AND bs.type = 'I'
AND bs.database_backup_lsn = @FullDatabaseBackupLSN
AND bs.backup_finish_date <= @RestoreToDate
ORDER BY bs.backup_finish_date DESC;

------------------------------------------------------------------------------
-- STEP 4
-- INSERT DIFFERENTIAL IF AVAILABLE
------------------------------------------------------------------------------

IF @DiffBackupDate IS NOT NULL
BEGIN

    INSERT INTO #Chain
    SELECT 2
          ,'DIFFERENTIAL'
          ,bs.backup_start_date
          ,bs.backup_finish_date
          ,bs.first_lsn
          ,bs.last_lsn
          ,bs.database_backup_lsn
          ,bmf.physical_device_name
    FROM msdb.dbo.backupset bs
    INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name = @DatabaseName
    AND bs.type = 'I'
    AND bs.backup_finish_date = @DiffBackupDate;
END

------------------------------------------------------------------------------
-- STEP 5
-- INSERT REQUIRED LOG BACKUPS
------------------------------------------------------------------------------

DECLARE @ChainStart DATETIME;

SET @ChainStart = (SELECT MAX(BackupFinishDate) FROM #Chain);

INSERT INTO #Chain
SELECT ROW_NUMBER() OVER(ORDER BY bs.backup_finish_date) + (SELECT MAX(RestoreSequence) FROM #Chain)
      ,'LOG'
      ,bs.backup_start_date
      ,bs.backup_finish_date
      ,bs.first_lsn
      ,bs.last_lsn
      ,bs.database_backup_lsn
      ,bmf.physical_device_name
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = @DatabaseName
AND bs.type = 'L'
AND bs.backup_finish_date > @ChainStart
AND bs.backup_finish_date <= @RestoreToDate
ORDER BY bs.backup_finish_date;

------------------------------------------------------------------------------
-- FINAL CHAIN
------------------------------------------------------------------------------

SELECT RestoreSequence
      ,BackupType
      ,BackupStartDate
      ,BackupFinishDate
      ,FirstLSN
      ,LastLSN
      ,DatabaseBackupLSN
      ,PhysicalDeviceName
FROM #Chain
ORDER BY RestoreSequence;
GO

/******************************************************************************
INTERPRETATION

FULL

    Full Backup required.

DIFFERENTIAL

    Latest Differential based on the Full Backup.

LOG

    Transaction Log backups required after the
    Full/Differential backup.

EXAMPLE

    1 FULL
    2 DIFFERENTIAL
    3 LOG
    4 LOG
    5 LOG

Restore Order

    FULL
        ->
    DIFFERENTIAL
        ->
    LOG
        ->
    LOG
        ->
    LOG
        ->
    RECOVERY

******************************************************************************/