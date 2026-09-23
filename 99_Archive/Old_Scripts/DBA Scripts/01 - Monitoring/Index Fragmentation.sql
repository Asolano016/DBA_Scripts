-- Index Fragmentation Summary
USE [DatabaseName]
GO

SELECT
    COUNT(*) AS TotalIndices,
    SUM(CASE WHEN avg_fragmentation_in_percent < 5 THEN 1 ELSE 0 END) AS OK,
    SUM(CASE WHEN avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN 1 ELSE 0 END) AS Reorganize,
    SUM(CASE WHEN avg_fragmentation_in_percent > 30 THEN 1 ELSE 0 END) AS Rebuild
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    'LIMITED'
)
WHERE page_count > 100;

USE [DatabaseName]
GO

-- Index Fragmentation List

SELECT
    OBJECT_NAME(ps.object_id) AS Tabla,
    i.name AS Indice,
    CAST(ps.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS FragmentacionPct,
    ps.page_count,
    CASE
        WHEN ps.avg_fragmentation_in_percent < 5 THEN 'OK'
        WHEN ps.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN 'REORGANIZE'
        WHEN ps.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
    END AS Recomendacion,
    CASE
        WHEN ps.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN
            'ALTER INDEX [' + i.name + '] ON [' +
            OBJECT_SCHEMA_NAME(ps.object_id) + '].[' +
            OBJECT_NAME(ps.object_id) + '] REORGANIZE;'

        WHEN ps.avg_fragmentation_in_percent > 30 THEN
            'ALTER INDEX [' + i.name + '] ON [' +
            OBJECT_SCHEMA_NAME(ps.object_id) + '].[' +
            OBJECT_NAME(ps.object_id) + '] REBUILD;'

        ELSE NULL
    END AS Comando
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    'LIMITED'
) ps
INNER JOIN sys.indexes i
    ON ps.object_id = i.object_id
    AND ps.index_id = i.index_id
WHERE
    ps.page_count > 100
    AND i.index_id > 0
ORDER BY ps.avg_fragmentation_in_percent DESC;

-- Reindex command list

SELECT
    CASE
        WHEN ps.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN
            'ALTER INDEX [' + i.name + '] ON [' +
            OBJECT_SCHEMA_NAME(ps.object_id) + '].[' +
            OBJECT_NAME(ps.object_id) + '] REORGANIZE;'

        WHEN ps.avg_fragmentation_in_percent > 30 THEN
            'ALTER INDEX [' + i.name + '] ON [' +
            OBJECT_SCHEMA_NAME(ps.object_id) + '].[' +
            OBJECT_NAME(ps.object_id) + '] REBUILD;'
    END AS Script
FROM sys.dm_db_index_physical_stats
(
    DB_ID(), NULL, NULL, NULL, 'LIMITED'
) ps
JOIN sys.indexes i
    ON ps.object_id = i.object_id
    AND ps.index_id = i.index_id
WHERE
    ps.page_count > 100
    AND i.index_id > 0
    AND ps.avg_fragmentation_in_percent >= 5;