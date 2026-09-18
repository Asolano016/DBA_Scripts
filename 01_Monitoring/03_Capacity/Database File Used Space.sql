-- ============================================================
-- Database File Space - Single Database
-- Run while connected to the target database
-- ============================================================

-- Log space via DBCC SQLPERF: compatible with ALL SQL Server versions
IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL DROP TABLE #LogSpace;
CREATE TABLE #LogSpace (
    DatabaseName NVARCHAR(128),
    LogSizeMB FLOAT,
    LogUsedPercent FLOAT,
    Status  INT
);
INSERT INTO #LogSpace EXEC ('DBCC SQLPERF(LOGSPACE) WITH NO_INFOMSGS');

-- Main query
SELECT
    -- File identity
    mf.database_id AS IntDatabaseID,
    DB_NAME(mf.database_id) AS DatabaseName,
    mf.file_id AS FileID,
    mf.data_space_id AS FilegroupID,
    fg.name AS FilegroupName,
    mf.name AS LogicalName,
    mf.physical_name AS PhysicalName,
    mf.type_desc AS FileType,
    mf.state_desc AS FileState,

    -- Allocated size on disk
    CAST(mf.size * 8.0 / 1048576 AS DECIMAL(18,4)) AS FileSizeGB
    -- Growth configuration
   ,mf.is_percent_growth AS IsPercentGrowth
   ,CASE mf.is_percent_growth
		 WHEN 1 THEN CAST(mf.growth AS VARCHAR(10)) + '%'
		 ELSE CAST(CAST(mf.growth * 8.0 / 1024 AS INT) AS VARCHAR(10)) + ' MB'
    END AS GrowthSetting
   ,CASE mf.max_size
		 WHEN -1 THEN 'Unlimited'
		 WHEN  0 THEN 'No growth'
 ELSE CAST(CAST(mf.max_size * 8.0 / 1048576 AS DECIMAL(18,2)) AS VARCHAR(20)) + ' GB'
    END AS MaxSizeSetting
    -- Internal space
    -- ROWS: filegroup level (SQL Server DMV limitation — same value across all files in the filegroup)
    -- LOG:  database level  (same value across all log files)
   ,CASE mf.type_desc
		WHEN 'ROWS' THEN CAST((fsu.total_page_count - fsu.unallocated_extent_page_count) * 8.0 / 1048576 AS DECIMAL(18,4))
		WHEN 'LOG'  THEN CAST(ls.LogSizeMB * ls.LogUsedPercent / 100.0 / 1024.0 AS DECIMAL(18,4))
    END AS InternalUsedGB
   ,CASE mf.type_desc
		 WHEN 'ROWS' THEN CAST(fsu.unallocated_extent_page_count * 8.0 / 1048576 AS DECIMAL(18,4))
		 WHEN 'LOG'  THEN CAST(ls.LogSizeMB * (100.0 - ls.LogUsedPercent) / 100.0 / 1024.0    AS DECIMAL(18,4))
    END AS InternalFreeGB
   ,CASE mf.type_desc
		 WHEN 'ROWS' THEN CAST(fsu.unallocated_extent_page_count * 100.0 / NULLIF(fsu.total_page_count, 0) AS DECIMAL(10,2))
		 WHEN 'LOG'  THEN CAST(100.0 - ls.LogUsedPercent AS DECIMAL(10,2))
    END AS InternalFreePercent
    -- Volume / disk level
   ,vs.volume_mount_point AS VolumeMountPoint
   ,CAST(vs.total_bytes / 1073741824.0 AS DECIMAL(18,4)) AS VolumeTotalGB
   ,CAST((vs.total_bytes - vs.available_bytes)   / 1073741824.0 AS DECIMAL(18,4)) AS VolumeUsedGB
   ,CAST(vs.available_bytes / 1073741824.0 AS DECIMAL(18,4)) AS VolumeFreeGB
   ,CAST(vs.available_bytes * 100.0 / NULLIF(vs.total_bytes, 0) AS DECIMAL(10,2)) AS VolumeFreePercent
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
LEFT JOIN sys.filegroups AS fg ON  fg.data_space_id = mf.data_space_id
LEFT JOIN sys.dm_db_file_space_usage AS fsu ON  fsu.filegroup_id = mf.data_space_id AND mf.type_desc = 'ROWS'
-- Log space: filter to current DB, join all LOG files to the same single row
LEFT JOIN #LogSpace AS ls ON  ls.DatabaseName = DB_NAME(mf.database_id) AND mf.type_desc    = 'LOG'
WHERE mf.database_id = DB_ID()
ORDER BY mf.type_desc DESC, mf.file_id;