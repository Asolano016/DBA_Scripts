-- ============================================================
-- Database Space Summary - All Databases (Instance Level)
-- One row per database per file type (ROWS | LOG)
-- Can be run from any database context
-- ============================================================

-- Log space via DBCC SQLPERF: compatible with ALL SQL Server versions
IF OBJECT_ID('tempdb..#LogSpace')       IS NOT NULL DROP TABLE #LogSpace;
IF OBJECT_ID('tempdb..#FilegroupSpace') IS NOT NULL DROP TABLE #FilegroupSpace;

CREATE TABLE #LogSpace (
    DatabaseName   NVARCHAR(128),
    LogSizeMB      FLOAT,
    LogUsedPercent FLOAT,
    Status         INT
);

CREATE TABLE #FilegroupSpace (
    DatabaseID  INT,
    FilegroupID INT,
    TotalPages  BIGINT,
    UsedPages   BIGINT,
    FreePages   BIGINT
);

-- Log space: single call covers all databases
INSERT INTO #LogSpace EXEC ('DBCC SQLPERF(LOGSPACE) WITH NO_INFOMSGS');

-- Internal data space: loop required (sys.dm_db_file_space_usage is per-DB DMV)
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

-- Summary query
-- CTEs aggregate each source independently to avoid double-counting
-- when filegroups contain multiple files
;WITH
-- Allocated file sizes and count per DB + file type
FileAlloc AS (
    SELECT
        database_id,
        type_desc,
        COUNT(*)                            AS FileCount,
        SUM(size * 8.0 / 1048576)           AS TotalSizeGB
    FROM sys.master_files
    GROUP BY database_id, type_desc
),
-- Internal data space: sum across all filegroups per DB
DataInternal AS (
    SELECT
        DatabaseID,
        SUM(TotalPages) * 8.0 / 1048576     AS TotalInternalGB,
        SUM(UsedPages)  * 8.0 / 1048576     AS UsedGB,
        SUM(FreePages)  * 8.0 / 1048576     AS FreeGB
    FROM #FilegroupSpace
    GROUP BY DatabaseID
),
-- Internal log space: one row per DB from DBCC SQLPERF
LogInternal AS (
    SELECT
        DatabaseName,
        LogSizeMB / 1024.0                                          AS TotalLogGB,
        LogSizeMB * LogUsedPercent / 100.0 / 1024.0                AS UsedGB,
        LogSizeMB * (100.0 - LogUsedPercent) / 100.0 / 1024.0      AS FreeGB
    FROM #LogSpace
)
SELECT
    DB_NAME(fa.database_id)                                         AS DatabaseName,
    fa.type_desc                                                    AS FileType,
    fa.FileCount,
    -- Allocated on disk (sum of all files of this type)
    CAST(fa.TotalSizeGB                                 AS DECIMAL(18,2)) AS TotalSizeGB,
    -- Internal space
    CASE fa.type_desc
        WHEN 'ROWS' THEN CAST(di.UsedGB                AS DECIMAL(18,2))
        WHEN 'LOG'  THEN CAST(li.UsedGB                AS DECIMAL(18,2))
    END                                                             AS InternalUsedGB,
    CASE fa.type_desc
        WHEN 'ROWS' THEN CAST(di.FreeGB                AS DECIMAL(18,2))
        WHEN 'LOG'  THEN CAST(li.FreeGB                AS DECIMAL(18,2))
    END                                                             AS InternalFreeGB,
    CASE fa.type_desc
        WHEN 'ROWS' THEN CAST(di.FreeGB  * 100.0 / NULLIF(di.TotalInternalGB, 0) AS DECIMAL(10,2))
        WHEN 'LOG'  THEN CAST(li.FreeGB  * 100.0 / NULLIF(li.TotalLogGB,      0) AS DECIMAL(10,2))
    END                                                             AS InternalFreePercent
FROM FileAlloc fa
LEFT JOIN DataInternal di ON  di.DatabaseID  = fa.database_id AND fa.type_desc = 'ROWS'
LEFT JOIN LogInternal  li ON  li.DatabaseName = DB_NAME(fa.database_id) AND fa.type_desc = 'LOG'
AND DatabaseName NOT IN ('master','admin','msdb','tempdb','model')
ORDER BY DB_NAME(fa.database_id), fa.type_desc DESC;   -- ROWS before LOG
