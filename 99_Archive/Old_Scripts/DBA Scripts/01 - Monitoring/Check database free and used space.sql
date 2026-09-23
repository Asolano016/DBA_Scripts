SELECT DB_NAME() AS DbName,
NAME,
size/128/1024.0 AS FileSizeGB,
size/128/1024.0 - CAST(FILEPROPERTY(NAME, 'SpaceUsed') AS INT)/128/1024.0 AS FreeSpaceGB,
(size/128/1024.0 - CAST(FILEPROPERTY(NAME, 'SpaceUsed') AS INT)/128/1024.0) / (size/128/1024.0) * 100 AS PercentFree
FROM sys.database_files
