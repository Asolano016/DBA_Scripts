/******************************************************************************
BACKUP RESTORE CHAIN ANALYSIS
-------------------------------------------------------------------------------

PURPOSE

    Analyze the backup chain for a database and identify the sequence
    of backups required for a restore operation.

USE CASES

    • Point-in-time recovery planning
    • Restore sequence validation
    • DR exercises
    • Recovery troubleshooting

******************************************************************************/

USE msdb;
GO

------------------------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------------------------

DECLARE @DatabaseName SYSNAME;
DECLARE @FinishDate DATETIME;
DECLARE @numDays INT;

SET @DatabaseName = 'DBNAME';
SET @numDays	  = 30;
SET @finishDate   = NULL --'2026-09-15 23:59:59';

------------------------------------------------------------------------------
-- BACKUP CHAIN
------------------------------------------------------------------------------

SELECT bs.database_name AS DatabaseName
      ,CASE bs.type
          WHEN 'D' THEN 'FULL'
          WHEN 'I' THEN 'DIFFERENTIAL'
          WHEN 'L' THEN 'LOG'
          WHEN 'F' THEN 'FILE'
          WHEN 'G' THEN 'DIFFERENTIAL FILE'
          WHEN 'P' THEN 'PARTIAL'
          WHEN 'Q' THEN 'DIFFERENTIAL PARTIAL'
       END AS BackupType
      ,bs.backup_start_date AS BackupStartDate
      ,bs.backup_finish_date AS BackupFinishDate
      ,bs.first_lsn AS FirstLsn
      ,bs.last_lsn AS LastLsn
      ,bs.database_backup_lsn AS DatabaseBackupLsn
      ,bs.checkpoint_lsn AS CheckpoinLsn
      ,bmf.physical_device_name AS PhysicalDeviceName
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.backup_start_date >= DATEADD(DAY,-@numDays,GETDATE())
AND (@finishDate IS NULL OR bs.backup_start_date <= @finishDate)
AND bs.database_name = @DatabaseName
ORDER BY bs.backup_finish_date;

------------------------------------------------------------------------------
-- LATEST FULL BACKUP
------------------------------------------------------------------------------

SELECT TOP (1) bs.database_name AS DatabaseName
      ,bs.backup_finish_date AS BackupFinishDate
      ,bs.first_lsn AS FirstLsn
      ,bs.last_lsn AS LastLsn
      ,bmf.physical_device_name AS PhysicalDeviceName
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.backup_start_date >= DATEADD(DAY,-@numDays,GETDATE())
AND (@finishDate IS NULL OR bs.backup_start_date <= @finishDate)
AND bs.database_name = @DatabaseName
AND bs.type = 'D'
ORDER BY bs.backup_finish_date DESC;

------------------------------------------------------------------------------
-- LATEST DIFFERENTIAL BACKUP
------------------------------------------------------------------------------

SELECT TOP (1) bs.database_name AS DatabaseName
      ,bs.backup_finish_date AS BackupFinishDate
      ,bs.first_lsn AS FirstLsn
      ,bs.last_lsn AS LastLsn
      ,bmf.physical_device_name AS PhysicalDeviceName
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.backup_start_date >= DATEADD(DAY,-@numDays,GETDATE())
AND (@finishDate IS NULL OR bs.backup_start_date <= @finishDate)
AND bs.database_name = @DatabaseName
AND bs.type = 'I'
ORDER BY bs.backup_finish_date DESC;

------------------------------------------------------------------------------
-- TRANSACTION LOG CHAIN
------------------------------------------------------------------------------

SELECT TOP (1) bs.database_name AS DatabaseName
      ,bs.backup_finish_date AS BackupFinishDate
      ,bs.first_lsn AS FirstLsn
      ,bs.last_lsn AS LastLsn
      ,bmf.physical_device_name AS PhysicalDeviceName
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.backup_start_date >= DATEADD(DAY,-@numDays,GETDATE())
AND (@finishDate IS NULL OR bs.backup_start_date <= @finishDate)
AND bs.database_name = @DatabaseName
AND bs.type = 'L'
ORDER BY bs.first_lsn;

/******************************************************************************
INTERPRETATION

FULL ONLY

    FULL
        ->
    RECOVERY

-------------------------------------------------------------------------------

FULL + DIFF

    FULL
        ->
    DIFF
        ->
    RECOVERY

-------------------------------------------------------------------------------

FULL + LOGS

    FULL
        ->
    LOG
        ->
    LOG
        ->
    LOG
        ->
    RECOVERY

-------------------------------------------------------------------------------

FULL + DIFF + LOGS

    FULL
        ->
    DIFF
        ->
    LOG
        ->
    LOG
        ->
    LOG
        ->
    RECOVERY

******************************************************************************/