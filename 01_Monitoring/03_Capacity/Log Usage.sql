USE [SQLInventory];
GO

SELECT
    DB_NAME() AS DatabaseName,

    -- Total Size
    --CAST(total_log_size_in_bytes/1024.0/1024 AS DECIMAL(12,2)) AS LogSizeMB,
    CAST(total_log_size_in_bytes/1024.0/1024/1024 AS DECIMAL(12,2)) AS LogSizeGB,
    --CAST(total_log_size_in_bytes/1024.0/1024/1024/1024 AS DECIMAL(12,4)) AS LogSizeTB,

    -- Used Space
    --CAST(used_log_space_in_bytes/1024.0/1024 AS DECIMAL(12,2)) AS UsedLogMB,
    CAST(used_log_space_in_bytes/1024.0/1024/1024 AS DECIMAL(12,2)) AS UsedLogGB,
    --CAST(used_log_space_in_bytes/1024.0/1024/1024/1024 AS DECIMAL(12,4)) AS UsedLogTB,

    -- Space free inside the tlog
    --CAST((total_log_size_in_bytes-used_log_space_in_bytes)/1024.0/1024 AS DECIMAL(12,2)) AS FreeLogMB,
    CAST((total_log_size_in_bytes-used_log_space_in_bytes)/1024.0/1024/1024 AS DECIMAL(12,2)) AS FreeLogGB,
    --CAST((total_log_size_in_bytes-used_log_space_in_bytes)/1024.0/1024/1024/1024 AS DECIMAL(12,4)) AS FreeLogTB,

    -- Percentage
    used_log_space_in_percent AS UsedPct,
    (100-used_log_space_in_percent) AS FreePct
FROM sys.dm_db_log_space_usage;