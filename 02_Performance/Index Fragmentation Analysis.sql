SELECT DB_NAME() AS 'Database'
	  ,'[' + s.[name] + '].[' + t.[name] +']' AS 'Table'
	  ,i.[name] AS 'Index'
	  ,ips.index_type_desc AS 'IndexType'
	  ,ips.avg_fragmentation_in_percent AS 'AvgFragmentationPercentage'
	  ,ips.page_count AS 'PageCount'
	  ,CASE 
		WHEN ips.avg_fragmentation_in_percent > 30
			THEN 'ALTER INDEX [' + i.[name] + '] ON [' + s.[name] + '].[' + t.[name] + '] REBUILD WITH (ONLINE = ON);'
	    ELSE 'ALTER INDEX [' + i.[name] + '] ON [' + s.[name] + '].[' + t.[name] + '] REORGANIZE;'
	   END 'ReindexingCommand'
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
INNER JOIN sys.tables t ON t.object_id = ips.object_id
INNER JOIN sys.schemas s on s.schema_id = t.schema_id
INNER JOIN sys.indexes i ON (i.object_id = ips.object_id) AND (i.index_id = ips.index_id)
WHERE ips.avg_fragmentation_in_percent > 5
ORDER BY ips.avg_fragmentation_in_percent DESC