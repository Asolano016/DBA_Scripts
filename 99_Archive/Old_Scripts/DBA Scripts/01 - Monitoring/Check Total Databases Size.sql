SELECT
    d.name AS DatabaseName,
    CAST(SUM(mf.size) * 8.0 / 1024 AS DECIMAL(18,2)) AS SizeMB,
    CAST(SUM(mf.size) * 8.0 / 1024 / 1024 AS DECIMAL(18,2)) AS SizeGB
FROM sys.master_files mf
INNER JOIN sys.databases d
    ON mf.database_id = d.database_id
GROUP BY d.name
ORDER BY SizeGB DESC;

