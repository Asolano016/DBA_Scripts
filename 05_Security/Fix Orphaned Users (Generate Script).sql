USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#tempOrphanedLogins') IS NOT NULL
	DROP TABLE #tempOrphanedLogins

CREATE TABLE #tempOrphanedLogins(
	DatabaseName NVARCHAR(MAX),
	LinkLogins NVARCHAR(MAX)
)

DECLARE @query NVARCHAR(MAX),
	    @SQLLogin NVARCHAR(MAX),
		@DatabaseName NVARCHAR(MAX);

SET @SQLLogin = 'usdgf_ods_admin'
SET @DatabaseName = ''

SET @query = "USE [?];

			IF '?' NOT IN ('master','msdb','tempdb','model','Admin')
			BEGIN
				INSERT INTO #tempOrphanedLogins
				SELECT '?' AS DatabaseName,'USE [?]; EXEC sp_change_users_login ''update_one'', ''' + d.name + ''', ''' + d.name + ''', NULL;' AS LinkLogins
				FROM sys.database_principals d
				INNER JOIN sys.server_principals s ON s.sid = d.sid
				WHERE s.type = 'S'
				AND s.is_disabled = 0
				--AND d.name = '" + @SQLLogin + "'
			END"

EXEC sp_MSforeachdb @query

SELECT DatabaseName 
	  ,LinkLogins
FROM #tempOrphanedLogins
ORDER BY DatabaseName
