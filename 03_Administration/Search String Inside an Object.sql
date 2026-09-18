--For all databases

USE [master]
GO

SET QUOTED_IDENTIFIER OFF;

DECLARE @SearchText NVARCHAR(MAX) = 'STRING'
DECLARE @sql NVARCHAR(MAX);

SET @sql = "USE [?];
SELECT '?' AS DatabaseName
	   ,[Scehma] = schema_name(o.schema_id)
	   ,o.Name
	   ,o.type_desc
	   ,m.definition
FROM sys.sql_modules m
INNER JOIN sys.objects o ON o.object_id = m.object_id
WHERE m.definition like '% " + @SearchText + "%'"

EXEC sp_MSforeachdb @sql

--For one database

USE [master]
GO

DECLARE @SearchText NVARCHAR(MAX) = 'STRING'

SELECT DB_NAME() AS DatabaseName
	 ,[Scehma] = schema_name(o.schema_id)
	 ,o.Name
	 ,o.type_desc
	 ,m.definition
FROM sys.sql_modules m
INNER JOIN sys.objects o
ON o.object_id = m.object_id
WHERE m.definition LIKE '%' + @SearchText + '%';
GO