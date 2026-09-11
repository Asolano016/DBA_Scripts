/*
   Successful Restore Operations - estilo SSMS Standard Report
   Requiere SQL Server 2017+ por STRING_AGG
*/
USE msdb;
GO

WITH media AS (
    SELECT 
        bs.backup_set_id,
        STRING_AGG(bmf.physical_device_name, '; ') WITHIN GROUP (ORDER BY bmf.media_set_id) AS devices
    FROM dbo.backupset bs
    LEFT JOIN dbo.backupmediafamily bmf
        ON bs.media_set_id = bmf.media_set_id
    GROUP BY bs.backup_set_id
)
SELECT
    UPPER(@@SERVERNAME)                                           AS [Server Name],
    rh.destination_database_name                                  AS [Database],
    rh.user_name                                                  AS [Restored By],
    CASE rh.restore_type
        WHEN 'D' THEN 'Database'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
        WHEN 'F' THEN 'File/Filegroup'
        WHEN 'G' THEN 'Filegroup'          -- raro, pero posible
        WHEN 'V' THEN 'Verifyonly'         -- si llega a aparecer
        ELSE rh.restore_type
    END                                                          AS [Restore Type],
    rh.restore_date                                              AS [Restore Completed],
    -- Nota: msdb no guarda el "start time" exacto del restore. Si lo necesitás, tomá de logs del agente/Extended Events.
    CASE 
        WHEN rh.recovery = 1 THEN 'WITH RECOVERY'
        WHEN rh.recovery = 0 AND rh.restart = 0 THEN 'NORECOVERY'
        WHEN rh.recovery = 0 AND rh.restart = 1 THEN 'STANDBY'
        ELSE NULL
    END                                                          AS [Recovery State],
    CASE WHEN rh.replace = 1 THEN 'WITH REPLACE' ELSE NULL END  AS [Replace],
    bs.server_name                                               AS [Backup Server],
    bs.database_name                                             AS [Backup Database (Source)],
    bs.backup_start_date                                         AS [Backup Start],
    bs.backup_finish_date                                        AS [Backup Finish],
    bs.type                                                      AS [Backup Type Code],
    CASE bs.type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
        WHEN 'F' THEN 'File/Filegroup'
        WHEN 'G' THEN 'Differential File'
        WHEN 'Q' THEN 'Copy-Only'
        ELSE bs.type
    END                                                          AS [Backup Type],
    bs.recovery_model                                            AS [Recovery Model],
    media.devices                                                AS [Backup Devices]
FROM dbo.restorehistory rh
LEFT JOIN dbo.backupset bs
  ON rh.backup_set_id = bs.backup_set_id
LEFT JOIN media
  ON bs.backup_set_id = media.backup_set_id
-- Filtro temporal opcional: últimos 90 días
WHERE rh.restore_date >= DATEADD(DAY, -90, SYSUTCDATETIME())
ORDER BY rh.restore_date DESC, rh.destination_database_name;