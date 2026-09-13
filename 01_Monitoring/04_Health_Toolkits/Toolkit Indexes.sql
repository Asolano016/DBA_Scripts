/******************************************************************************
SQL SERVER INDEX HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------
PURPOSE

This toolkit provides a structured approach for evaluating index health,
identifying missing index recommendations, detecting duplicate/overlapping indexes,
locating unused/write-heavy indexes, and safely analyzing fragmentation.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Instance Uptime & Index Usage Baseline
2. High-Impact Missing Index Recommendations
3. Unused Indexes (High Updates / Zero Reads)
4. Low-Value Write-Heavy Indexes (Updates >> Reads)
5. Duplicate & Overlapping Index Detection
6. Safe Index Fragmentation Analysis (Filtered by Page Count)
7. Largest Indexes by Reserved Space
8. Key Lookup Identification & Costs
9. Comprehensive Index Usage Statistics
10. Index Operational Contention (Lock & Latch Splits)
11. Executive Summary & Index Triage Matrix

RECOMMENDED TROUBLESHOOTING FLOW

    1. Check Instance Uptime Baseline (Section 1)
    2. Review High-Impact Missing Indexes (Section 2)
    3. Identify Duplicate & Redundant Indexes (Section 5)
    4. Review Unused & Write-Heavy Indexes (Section 3 & 4)

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    INSTANCE UPTIME & INDEX USAGE BASELINE
-------------------------------------------------------------------------------
.PURPOSE
    Establish how long SQL Server has been running since last restart.

.CRITICAL SAFETY WARNING
    sys.dm_db_index_usage_stats resets when SQL Server restarts or when an
    index is rebuilt. Never drop an "unused" index if uptime is low (<30 days)
    or before reviewing month-end / quarter-end reporting workloads!
-----------------------------------------------------------------------------*/

SELECT
    GETDATE() AS CaptureTime,
    DB_NAME() AS CurrentDatabaseContext,
    sqlserver_start_time,
    DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS DaysUptime,
    DATEDIFF(HOUR, sqlserver_start_time, GETDATE()) AS HoursUptime
FROM sys.dm_os_sys_info;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    HIGH-IMPACT MISSING INDEX RECOMMENDATIONS
-------------------------------------------------------------------------------
.PURPOSE
    Identify missing index recommendations scored by user impact and seeks.
-----------------------------------------------------------------------------*/

SELECT TOP (20)
    CAST(migs.avg_user_impact AS DECIMAL(5,2)) AS AvgUserImpactPct,
    migs.user_seeks AS UserSeeks,
    migs.user_scans AS UserScans,
    migs.last_user_seek AS LastUserSeekTime,
    DB_NAME(mid.database_id) AS DatabaseName,
    mid.statement AS TableName,
    mid.equality_columns AS EqualityColumns,
    mid.inequality_columns AS InequalityColumns,
    mid.included_columns AS IncludedColumns,
    'CREATE NONCLUSTERED INDEX IX_' +
        REPLACE(REPLACE(REPLACE(REPLACE(mid.statement, '[', ''), ']', ''), ' ', '_'), '.', '_') +
        '_' + CAST(migs.group_handle AS VARCHAR(10)) + ' ON ' + mid.statement +
        ' (' + ISNULL(mid.equality_columns, '') +
        CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ', ' ELSE '' END +
        ISNULL(mid.inequality_columns, '') + ')' +
        ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS ProposedCreateIndexScript
FROM sys.dm_db_missing_index_details mid
INNER JOIN sys.dm_db_missing_index_groups mig
    ON mid.index_handle = mig.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats migs
    ON mig.index_group_handle = migs.group_handle
WHERE mid.database_id = DB_ID()
ORDER BY (migs.avg_user_impact * migs.user_seeks) DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    UNUSED INDEXES (HIGH UPDATES / ZERO READS)
-------------------------------------------------------------------------------
.PURPOSE
    Identify nonclustered indexes that have received data modifications but zero reads.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    SCHEMA_NAME(t.schema_id) + '.' + OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ISNULL(us.user_updates, 0) AS UserUpdates,
    ISNULL(us.user_seeks, 0) AS UserSeeks,
    ISNULL(us.user_scans, 0) AS UserScans,
    ISNULL(us.user_lookups, 0) AS UserLookups,
    us.last_user_update AS LastUpdateDate
FROM sys.indexes i
INNER JOIN sys.tables t
    ON i.object_id = t.object_id
LEFT JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
    AND i.index_id = us.index_id
    AND us.database_id = DB_ID()
WHERE i.index_id > 1
  AND i.is_primary_key = 0
  AND i.is_unique = 0
  AND i.is_unique_constraint = 0
  AND ISNULL(us.user_seeks, 0) = 0
  AND ISNULL(us.user_scans, 0) = 0
  AND ISNULL(us.user_lookups, 0) = 0
ORDER BY ISNULL(us.user_updates, 0) DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    LOW-VALUE WRITE-HEAVY INDEXES (UPDATES >> READS)
-------------------------------------------------------------------------------
.PURPOSE
    Identify indexes where the cost of write maintenance significantly exceeds read benefit.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    SCHEMA_NAME(t.schema_id) + '.' + OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0)) AS TotalReads,
    ISNULL(us.user_updates, 0) AS TotalUpdates,
    CAST(ISNULL(us.user_updates, 0) AS FLOAT) / NULLIF((ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0)), 0) AS UpdateToReadRatio
FROM sys.indexes i
INNER JOIN sys.tables t
    ON i.object_id = t.object_id
LEFT JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
    AND i.index_id = us.index_id
    AND us.database_id = DB_ID()
WHERE i.index_id > 1
  AND i.is_primary_key = 0
  AND i.is_unique = 0
  AND ISNULL(us.user_updates, 0) > 1000
  AND (ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0)) < (ISNULL(us.user_updates, 0) * 0.1)
ORDER BY TotalUpdates DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    DUPLICATE & OVERLAPPING INDEX DETECTION
-------------------------------------------------------------------------------
.PURPOSE
    Identify indexes sharing identical or overlapping leading key columns.
-----------------------------------------------------------------------------*/

WITH IndexKeyColumns AS
(
    SELECT
        ic.object_id,
        ic.index_id,
        STUFF((
            SELECT ', ' + c.name + CASE WHEN ic2.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
            FROM sys.index_columns ic2
            INNER JOIN sys.columns c
                ON ic2.object_id = c.object_id
                AND ic2.column_id = c.column_id
            WHERE ic2.object_id = ic.object_id
              AND ic2.index_id = ic.index_id
              AND ic2.is_included_column = 0
            ORDER BY ic2.key_ordinal
            FOR XML PATH('')
        ), 1, 2, '') AS KeyColumnsList,
        STUFF((
            SELECT ', ' + c.name
            FROM sys.index_columns ic2
            INNER JOIN sys.columns c
                ON ic2.object_id = c.object_id
                AND ic2.column_id = c.column_id
            WHERE ic2.object_id = ic.object_id
              AND ic2.index_id = ic.index_id
              AND ic2.is_included_column = 1
            ORDER BY ic2.index_column_id
            FOR XML PATH('')
        ), 1, 2, '') AS IncludedColumnsList
    FROM sys.index_columns ic
    GROUP BY ic.object_id, ic.index_id
)
SELECT
    SCHEMA_NAME(t.schema_id) + '.' + t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ikc.KeyColumnsList,
    ikc.IncludedColumnsList
FROM sys.indexes i
INNER JOIN sys.tables t
    ON i.object_id = t.object_id
INNER JOIN IndexKeyColumns ikc
    ON i.object_id = ikc.object_id
    AND i.index_id = ikc.index_id
WHERE EXISTS
(
    SELECT 1
    FROM IndexKeyColumns ikc2
    WHERE ikc2.object_id = ikc.object_id
      AND ikc2.index_id <> ikc.index_id
      AND (
          ikc2.KeyColumnsList = ikc.KeyColumnsList
          OR ikc2.KeyColumnsList LIKE ikc.KeyColumnsList + ',%'
      )
)
ORDER BY TableName, ikc.KeyColumnsList;
GO

/*-----------------------------------------------------------------------------
    SECTION 6
    SAFE INDEX FRAGMENTATION ANALYSIS (>1,000 PAGES)
-------------------------------------------------------------------------------
.PURPOSE
    Review index fragmentation levels safely on tables with >1,000 pages.

.SAFETY GUARD
    Scans with 'LIMITED' mode and filters small tables to prevent I/O saturation.
-----------------------------------------------------------------------------*/

SELECT TOP (50)
    SCHEMA_NAME(t.schema_id) + '.' + t.name AS TableName,
    i.name AS IndexName,
    ps.index_type_desc AS IndexType,
    ps.page_count AS PageCount,
    (ps.page_count * 8) / 1024 AS SizeMB,
    CAST(ps.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS AvgFragPercent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
INNER JOIN sys.indexes i
    ON ps.object_id = i.object_id
    AND ps.index_id = i.index_id
INNER JOIN sys.tables t
    ON ps.object_id = t.object_id
WHERE ps.page_count > 1000
  AND ps.index_id > 0
ORDER BY ps.avg_fragmentation_in_percent DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 7
    LARGEST INDEXES BY RESERVED SPACE
-------------------------------------------------------------------------------
.PURPOSE
    Identify the largest indexes consuming storage in the current database.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    SCHEMA_NAME(t.schema_id) + '.' + t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    SUM(a.total_pages) * 8 / 1024 AS TotalReservedMB,
    SUM(a.used_pages) * 8 / 1024 AS UsedMB
FROM sys.partitions p
INNER JOIN sys.allocation_units a
    ON p.partition_id = a.container_id
INNER JOIN sys.indexes i
    ON p.object_id = i.object_id
    AND p.index_id = i.index_id
INNER JOIN sys.tables t
    ON i.object_id = t.object_id
GROUP BY
    SCHEMA_NAME(t.schema_id),
    t.name,
    i.name,
    i.type_desc
ORDER BY TotalReservedMB DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 8
    KEY LOOKUP IDENTIFICATION & COSTS
-------------------------------------------------------------------------------
.PURPOSE
    Identify nonclustered indexes causing high numbers of clustered key lookups.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    SCHEMA_NAME(t.schema_id) + '.' + t.name AS TableName,
    i.name AS IndexName,
    us.user_lookups AS ClusteredKeyLookups,
    us.user_seeks AS Seeks,
    us.user_scans AS Scans
FROM sys.indexes i
INNER JOIN sys.tables t
    ON i.object_id = t.object_id
INNER JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
    AND i.index_id = us.index_id
WHERE us.database_id = DB_ID()
  AND us.user_lookups > 0
ORDER BY us.user_lookups DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 9
    INDEX OPERATIONAL CONTENTION (LOCK & LATCH SPLITS)
-------------------------------------------------------------------------------
.PURPOSE
    Identify indexes experiencing high row lock waits, page latch waits, or page splits.
-----------------------------------------------------------------------------*/

SELECT TOP (25)
    SCHEMA_NAME(t.schema_id) + '.' + t.name AS TableName,
    i.name AS IndexName,
    ios.leaf_insert_count AS LeafInserts,
    ios.leaf_update_count AS LeafUpdates,
    ios.leaf_delete_count AS LeafDeletes,
    ios.leaf_allocation_count AS PageSplits,
    ios.row_lock_wait_count AS RowLockWaits,
    ios.row_lock_wait_in_ms AS RowLockWaitMs,
    ios.page_latch_wait_count AS PageLatchWaits,
    ios.page_latch_wait_in_ms AS PageLatchWaitMs
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) ios
INNER JOIN sys.indexes i
    ON ios.object_id = i.object_id
    AND ios.index_id = i.index_id
INNER JOIN sys.tables t
    ON ios.object_id = t.object_id
ORDER BY ios.row_lock_wait_in_ms + ios.page_latch_wait_in_ms DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 10
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------
.PURPOSE
    High-level index health summary for the current database context.
-----------------------------------------------------------------------------*/

SELECT
    (SELECT DATEDIFF(DAY, sqlserver_start_time, GETDATE()) FROM sys.dm_os_sys_info) AS UptimeDays,
    (SELECT COUNT(*) FROM sys.dm_db_missing_index_details WHERE database_id = DB_ID()) AS MissingIndexCount,
    (SELECT COUNT(*) FROM sys.indexes WHERE index_id > 0) AS TotalIndexesCount,
    (SELECT COUNT(*) FROM sys.dm_db_index_usage_stats WHERE database_id = DB_ID() AND user_seeks = 0 AND user_scans = 0 AND user_lookups = 0 AND user_updates > 100) AS UnusedWriteHeavyIndexes;
GO

/******************************************************************************
FINAL DBA TRIAGE MATRIX
-------------------------------------------------------------------------------
INDEX HEALTH SYMPTOM                ACTIONABLE NEXT STEP
-------------------------------------------------------------------------------
High Missing Index Impact           --> Validate & create covering nonclustered index (Section 2)
Duplicate / Overlapping Indexes     --> Consolidate duplicate definitions (Section 5)
Unused Indexes with High Updates    --> Confirm uptime (>30d), then drop to save I/O (Section 3)
High Key Lookups                    --> Add missing columns to nonclustered index INCLUDE list
High Page Latch Waits & Page Splits --> Review primary key clustered index GUID vs IDENTITY
******************************************************************************/
