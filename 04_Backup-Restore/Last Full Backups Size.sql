SELECT
    bs.database_name,
    bs.backup_finish_date,
    CAST(bs.backup_size / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(18,2)) AS BackupSizeGB,
    bmf.physical_device_name
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE bs.type = 'D'
AND bs.database_name IN
(
    'API_ARCA',
    'Cic',
    'CRA_PAISES',
    'DHLParams',
    'ExpoSimple',
    'FactDC',
    'FactSQL',
    'Origenregional_Ar',
    'RBS',
    'ReportServer',
    'ReportServerTempDB',
    'SanHist',
    'SAP'
)
AND bs.backup_finish_date =
(
    SELECT MAX(bs2.backup_finish_date)
    FROM msdb.dbo.backupset bs2
    WHERE bs2.database_name = bs.database_name
      AND bs2.type = 'D'
)
ORDER BY BackupSizeGB DESC;