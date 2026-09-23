USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

SELECT "--SHRINK " + d.name +  " Transaction Log, Actual Log Size(MB): " + CAST(m.size * 8/1024 AS VARCHAR(15)) + "

	    USE [" + d.name + "]
		GO
		DBCC SHRINKFILE (N'" + m.name + "', 0)
		GO
		"
FROM sys.master_files m
INNER JOIN sys.databases d ON d.database_id = m.database_id
WHERE d.name NOT IN ('tempdb','master','msdb','model','Admin')
AND m.type = 1
ORDER BY m.size
GO