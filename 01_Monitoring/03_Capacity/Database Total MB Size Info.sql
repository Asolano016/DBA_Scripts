USE [SQLInventory]; -- Reemplaza con el nombre de tu base de datos
GO

SELECT DB_NAME() AS DatabaseName
      ,SUM(size * 8 / 1024) AS TotalSizeMB -- Tamaño total en MB
      ,SUM(CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) * 8 / 1024) AS UsedSpaceMB -- Espacio utilizado en MB
      ,SUM((size - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)) * 8 / 1024) AS FreeSpaceMB -- Espacio libre en MB
FROM 
    sys.master_files
WHERE 
    DB_NAME(database_id) = DB_NAME()
GROUP BY 
    database_id;