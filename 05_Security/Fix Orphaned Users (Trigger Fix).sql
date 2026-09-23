--------------- JUST ONE USER --------------- 

EXEC sp_change_users_login 'Report';

EXEC sp_change_users_login 'Auto_Fix', 'USERNAME', NULL
GO

--------------- ALL SQL LOGINS --------------- 

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @tOrphanedLogins TABLE (
	UserName NVARCHAR(MAX),
	UserSID NVARCHAR(MAX)
)

INSERT INTO @tOrphanedLogins
EXEC sp_change_users_login 'Report';


SELECT UserName, "EXEC sp_change_users_login 'Auto_Fix', '" + UserName + "', NULL;"
FROM @tOrphanedLogins 
--WHERE UserName IN ('LOGINNAME'
--				  ,'LOGINNAME'
--				  ,'LOGINNAME')

--------------- ALL SQL LOGINS + ALL DATABASES ---------------

SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#tOrphanedLogins', 'U') IS NOT NULL
	DROP TABLE #tOrphanedLogins

DECLARE @script VARCHAR(MAX)

CREATE TABLE #tOrphanedLogins(
	DatabaseName NVARCHAR(MAX),
	UserName NVARCHAR(MAX),
	UserSID NVARCHAR(MAX)
)

SET @script = "USE [?];
			   
			   SET QUOTED_IDENTIFIER OFF;

			   DECLARE @tOrphanedLogins TABLE (
					UserName NVARCHAR(MAX),
					UserSID NVARCHAR(MAX)
			   )
			   
			   INSERT INTO @tOrphanedLogins
			   EXEC sp_change_users_login 'Report';

			   INSERT INTO #tOrphanedLogins
			   SELECT '?', UserName, ""USE [?]; EXEC sp_change_users_login 'Auto_Fix', '"" + UserName + ""', NULL;""
			   FROM @tOrphanedLogins"

EXEC sp_MSforeachdb @script

SELECT * FROM #tOrphanedLogins
--WHERE UserName IN ('LOGINNAME'
--				  ,'LOGINNAME'
--				  ,'LOGINNAME')

