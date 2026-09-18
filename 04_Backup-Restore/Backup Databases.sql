/******************************************************************************
GENERATE FULL BACKUP COMMANDS

PURPOSE

    Generate BACKUP DATABASE commands automatically.

RULES

    <= 500 GB
        Generate 1 backup file

    > 500 GB
        Generate 4 striped backup files

NOTES

    Script only generates commands.

******************************************************************************/

USE master;
GO

DECLARE @BackupPath  NVARCHAR(max);
DECLARE @BackupSufix NVARCHAR(max);
DECLARE @DatabaseFilter NVARCHAR(max);

SET @BackupPath  = N'X:\SQLBackups\';
SET @BackupSufix = N'_FULL';
SET @DatabaseFilter = 'AndresTest';


;WITH DatabaseSize AS
(
    SELECT d.name AS DatabaseName
          ,SUM(m.size) * 8.0 / 1024 / 1024 AS DatabaseSizeGB
    FROM sys.databases d
    INNER JOIN sys.master_files m ON d.database_id = m.database_id
    WHERE d.name NOT IN ('master','model','msdb','tempdb','Admin')
    AND (ISNULL(@DatabaseFilter,'') = '' OR d.name IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@DatabaseFilter, ',')))
    GROUP BY d.name
)

SELECT
    '-- Database: ' + DatabaseName
    + CHAR(13) + CHAR(10)
    + '-- Size (GB): ' + CAST(CAST(DatabaseSizeGB AS DECIMAL(18,2)) AS VARCHAR(50))
    + CHAR(13) + CHAR(10)
    + CASE

        ----------------------------------------------------------------------
        -- SMALL / MEDIUM DATABASES (1 FILE)
        ----------------------------------------------------------------------

        WHEN DatabaseSizeGB <= 500 THEN

            'BACKUP DATABASE [' + DatabaseName + ']
TO DISK = N''' + @BackupPath + DatabaseName + @BackupSufix + '.bak''
WITH INIT, COMPRESSION, COPY_ONLY, CHECKSUM, STATS = 10;
GO'

        ----------------------------------------------------------------------
        -- LARGE DATABASES (4 STRIPES)
        ----------------------------------------------------------------------

        ELSE

            'BACKUP DATABASE [' + DatabaseName + ']
TO DISK = N''' + @BackupPath + DatabaseName + @BackupSufix + '_1.bak''
  ,DISK = N''' + @BackupPath + DatabaseName + @BackupSufix + '_2.bak''
  ,DISK = N''' + @BackupPath + DatabaseName + @BackupSufix + '_3.bak''
  ,DISK = N''' + @BackupPath + DatabaseName + @BackupSufix + '_4.bak''
WITH INIT, COMPRESSION, COPY_ONLY, CHECKSUM, STATS = 10;
GO'
      END AS BackupCommand
FROM DatabaseSize
ORDER BY DatabaseSizeGB DESC;