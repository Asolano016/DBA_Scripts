SET QUOTED_IDENTIFIER OFF
GO

DECLARE @objectName VARCHAR(100) = 'tPAR'
DECLARE @sql VARCHAR(MAX)

SET @sql = "USE [?];
SELECT @@SERVERNAME AS [ServerName]
	  ,'?' AS [DatabaseName]
	  ,o.object_id AS [ObjectName]
	  ,s.name AS [SchemaName]
	  ,o.type_desc AS [TypeDesc]
	  ,o.create_date AS [CreateDate]
	  ,o.modify_date AS [ModifyDate]
FROM sys.objects o
INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.[name] = '" + @objectName + "'"

EXEC sp_MSforeachdb @sql