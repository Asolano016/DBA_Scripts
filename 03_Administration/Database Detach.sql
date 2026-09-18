USE [master]
GO

--DETACH

SET QUOTED_IDENTIFIER OFF
GO

SELECT "USE [master];" + CHAR(13)+CHAR(10) +
	   "ALTER DATABASE [" + [name] + "] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE;"  + CHAR(13)+CHAR(10) +
	   "EXEC master.dbo.sp_detach_db @dbname = N'" + [name] + "';" AS 'DetachScript'
FROM sys.databases
WHERE [name] NOT IN ('tempdb','master','msdb','model','Admin')
--AND [name] = 'DBNAME' -- Detach one database
ORDER BY [name]

