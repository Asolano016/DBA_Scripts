-- ============================================================
-- Database File Space - All Databases (Instance Level)
-- Can be run from any database context
-- ============================================================

-- Log space via DBCC SQLPERF: compatible with ALL SQL Server versions
IF OBJECT_ID('tempdb..#LogSpace')       IS NOT NULL DROP TABLE #LogSpace;
IF OBJECT_ID('tempdb..#FilegroupSpace') IS NOT NULL DROP TABLE #FilegroupSpace;
IF OBJECT_ID('tempdb..#FilegroupNames') IS NOT NULL DROP TABLE #FilegroupNames;

CREATE TABLE #LogSpace (
    DatabaseName NVARCHAR(128),
    LogSizeMB FLOAT,
    LogUsedPercent FLOAT,
    Status INT
);

CREATE TABLE #FilegroupSpace (
    DatabaseID  INT,
    FilegroupID INT,
    TotalPages  BIGINT,
    UsedPages   BIGINT,
    FreePages   BIGINT
);

CREATE TABLE #FilegroupNames (
    DatabaseID    INT,
    FilegroupID   INT,
    FilegroupName NVARCHAR(128)
);

-- Log space: single call covers all databases
INSERT INTO #LogSpace EXEC ('DBCC SQLPERF(LOGSPACE) WITH NO_INFOMSGS');

-- Internal data space + filegroup names: loop required
-- (sys.dm_db_file_space_usage and sys.filegroups are per-DB DMVs)
DECLARE @DbName NVARCHAR(128);
DECLARE @DbID   INT;
DECLARE @SQL    NVARCHAR(MAX);

DECLARE cur_db CURSOR LOCAL FAST_FORWARD FOR
    SELECT name, database_id
    FROM sys.databases
    WHERE state_desc = 'ONLINE'
    ORDER BY database_id;

OPEN cur_db;
FETCH NEXT FROM cur_db INTO @DbName, @DbID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
        USE ' + QUOTENAME(@DbName) + N';

        INSERT INTO #FilegroupSpace (DatabaseID, FilegroupID, TotalPages, UsedPages, FreePages)
        SELECT
            ' + CAST(@DbID AS NVARCHAR(10)) + N',
            filegroup_id,
            SUM(total_page_count),
            SUM(total_page_count - unallocated_extent_page_count),
            SUM(unallocated_extent_page_count)
        FROM sys.dm_db_file_space_usage
        GROUP BY filegroup_id;

        INSERT INTO #FilegroupNames (DatabaseID, FilegroupID, FilegroupName)
        SELECT
            ' + CAST(@DbID AS NVARCHAR(10)) + N',
            data_space_id,
            name
        FROM sys.filegroups;
    ';

    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        -- Skip databases that are not accessible (AG secondary, restoring, snapshots, etc.)
    END CATCH;

    FETCH NEXT FROM cur_db INTO @DbName, @DbID;
END;

CLOSE cur_db;
DEALLOCATE cur_db;

-- Main query
SELECT
    -- File identity
    mf.database_id AS IntDatabaseID,
    DB_NAME(mf.database_id) AS DatabaseName,
    mf.file_id AS FileID,
    mf.data_space_id AS FilegroupID,
    fn.FilegroupName AS FilegroupName,
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
		WHEN 'ROWS' THEN CAST(fgs.UsedPages * 8.0 / 1048576 AS DECIMAL(18,4))
		WHEN 'LOG'  THEN CAST(ls.LogSizeMB * ls.LogUsedPercent / 100.0 / 1024.0 AS DECIMAL(18,4))
    END AS InternalUsedGB
   ,CASE mf.type_desc
		WHEN 'ROWS' THEN CAST(fgs.FreePages * 8.0 / 1048576 AS DECIMAL(18,4))
		WHEN 'LOG'  THEN CAST(ls.LogSizeMB * (100.0 - ls.LogUsedPercent) / 100.0 / 1024.0 AS DECIMAL(18,4))
    END AS InternalFreeGB
   ,CASE mf.type_desc
		WHEN 'ROWS' THEN CAST(fgs.FreePages * 100.0 / NULLIF(fgs.TotalPages, 0) AS DECIMAL(10,2))
		WHEN 'LOG'  THEN CAST(100.0 - ls.LogUsedPercent AS DECIMAL(10,2))
    END AS InternalFreePercent
    -- Volume / disk level
   ,vs.volume_mount_point AS VolumeMountPoint
   ,CAST(vs.total_bytes / 1073741824.0 AS DECIMAL(18,4)) AS VolumeTotalGB
   ,CAST((vs.total_bytes - vs.available_bytes) / 1073741824.0 AS DECIMAL(18,4)) AS VolumeUsedGB
   ,CAST(vs.available_bytes / 1073741824.0 AS DECIMAL(18,4)) AS VolumeFreeGB
   ,CAST(vs.available_bytes * 100.0 / NULLIF(vs.total_bytes, 0) AS DECIMAL(10,2)) AS VolumeFreePercent
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
LEFT JOIN #FilegroupNames AS fn ON fn.DatabaseID = mf.database_id AND fn.FilegroupID = mf.data_space_id
LEFT JOIN #FilegroupSpace AS fgs ON fgs.DatabaseID = mf.database_id AND fgs.FilegroupID = mf.data_space_id AND mf.type_desc = 'ROWS'
-- Log space: join all LOG files to their DB row from DBCC SQLPERF
LEFT JOIN #LogSpace AS ls ON ls.DatabaseName = DB_NAME(mf.database_id) AND mf.type_desc = 'LOG'
ORDER BY DB_NAME(mf.database_id), mf.type_desc DESC, mf.file_id;
