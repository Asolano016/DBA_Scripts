SELECT  
    GETDATE() AS RunTime,
    vs.volume_mount_point AS Drive,

    -- GB values
    CAST(vs.total_bytes / 1024.0 / 1024 / 1024 AS DECIMAL(12,2)) AS TotalGB,
    CAST(vs.available_bytes / 1024.0 / 1024 / 1024 AS DECIMAL(12,2)) AS FreeGB,
    CAST((vs.total_bytes - vs.available_bytes) / 1024.0 / 1024 / 1024 AS DECIMAL(12,2)) AS UsedGB,

    -- TB values
    CAST(vs.total_bytes / 1024.0 / 1024 / 1024 / 1024 AS DECIMAL(12,2)) AS TotalTB,
    CAST(vs.available_bytes / 1024.0 / 1024 / 1024 / 1024 AS DECIMAL(12,2)) AS FreeTB,
    CAST((vs.total_bytes - vs.available_bytes) / 1024.0 / 1024 / 1024 / 1024 AS DECIMAL(12,2)) AS UsedTB,

    -- Percent free
    CAST((vs.available_bytes * 100.0 / vs.total_bytes) AS DECIMAL(5,2)) AS FreePct

FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
--WHERE mf.type_desc = 'LOG'
--AND vs.volume_mount_point = 'E:\'
GROUP BY vs.volume_mount_point, vs.total_bytes, vs.available_bytes
ORDER BY FreePct;