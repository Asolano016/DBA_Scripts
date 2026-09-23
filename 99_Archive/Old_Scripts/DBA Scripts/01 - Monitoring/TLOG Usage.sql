USE DBNAME;
GO

SELECT
    DB_NAME() AS DatabaseName,

    -- Tamaño total
    CAST(total_log_size_in_bytes/1024.0/1024 AS DECIMAL(12,2)) AS LogSizeMB,
    CAST(total_log_size_in_bytes/1024.0/1024/1024 AS DECIMAL(12,2)) AS LogSizeGB,
    CAST(total_log_size_in_bytes/1024.0/1024/1024/1024 AS DECIMAL(12,4)) AS LogSizeTB,

    -- Espacio usado
    CAST(used_log_space_in_bytes/1024.0/1024 AS DECIMAL(12,2)) AS UsedLogMB,
    CAST(used_log_space_in_bytes/1024.0/1024/1024 AS DECIMAL(12,2)) AS UsedLogGB,
    CAST(used_log_space_in_bytes/1024.0/1024/1024/1024 AS DECIMAL(12,4)) AS UsedLogTB,

    -- Espacio libre dentro del log
    CAST((total_log_size_in_bytes-used_log_space_in_bytes)/1024.0/1024 AS DECIMAL(12,2)) AS FreeLogMB,
    CAST((total_log_size_in_bytes-used_log_space_in_bytes)/1024.0/1024/1024 AS DECIMAL(12,2)) AS FreeLogGB,
    CAST((total_log_size_in_bytes-used_log_space_in_bytes)/1024.0/1024/1024/1024 AS DECIMAL(12,4)) AS FreeLogTB,

    -- Porcentajes
    used_log_space_in_percent AS UsedPct,
    (100-used_log_space_in_percent) AS FreePct

FROM sys.dm_db_log_space_usage;

DBCC SQLPERF (LOGSPACE);
GO



USE master;
GO
ALTER DATABASE YourDBName
MODIFY FILE (NAME = CargoWiseOneDFOBNJPRO_log, MAXSIZE = 2609152);
GO
