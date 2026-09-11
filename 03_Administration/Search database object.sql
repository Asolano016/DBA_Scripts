SET QUOTED_IDENTIFIER OFF
GO

DECLARE @sql VARCHAR(MAX)

SET @sql = "SELECT @@SERVERNAME AS [ServerName]
	              ,DB_NAME() AS [DatabaseName], * 
	        FROM sys.objects
		    WHERE name = 'ep_BackupDb'"

EXEC sp_MSforeachdb @sql