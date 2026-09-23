--For all databases

SET QUOTED_IDENTIFIER OFF;

DECLARE @sql NVARCHAR(MAX);

SET @sql = "SELECT '?' AS DatabaseName
				   ,[Scehma] = schema_name(o.schema_id)
				   ,o.Name
				   ,o.type_desc
				   ,m.definition
			FROM sys.sql_modules m
			INNER JOIN sys.objects o
			ON o.object_id = m.object_id
			WHERE m.definition like '%whoami%'"

EXEC sp_MSforeachdb @sql

--For one database

USE [master]
GO

SELECT DB_NAME() AS DatabaseName
	 ,[Scehma] = schema_name(o.schema_id)
	 ,o.Name
	 ,o.type_desc
	 ,m.definition
FROM sys.sql_modules m
INNER JOIN sys.objects o
ON o.object_id = m.object_id
WHERE m.definition like '%whoami%'
GO