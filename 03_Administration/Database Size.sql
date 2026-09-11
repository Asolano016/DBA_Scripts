USE [TuBaseDeDatos]; -- Reemplaza con el nombre de tu base de datos
GO

SELECT 
    DB_NAME() AS BaseDeDatos,
    SUM(size * 8 / 1024) AS TamañoTotalMB, -- Tamaño total en MB
    SUM(CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) * 8 / 1024) AS EspacioUtilizadoMB, -- Espacio utilizado en MB
    SUM((size - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)) * 8 / 1024) AS EspacioLibreMB -- Espacio libre en MB
FROM 
    sys.master_files
WHERE 
    DB_NAME(database_id) = DB_NAME()
GROUP BY 
    database_id;