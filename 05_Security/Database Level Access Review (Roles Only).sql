USE [master]
GO

SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#tDatabaseRole') IS NOT NULL
	DROP TABLE #tDatabaseRole

DECLARE @query NVARCHAR(MAX);

CREATE TABLE #tDatabaseRole(
	ServerName VARCHAR(MAX),
	DatabaseName VARCHAR(MAX),
	DatabaseType VARCHAR(MAX),
	LoginName  VARCHAR(MAX),
	LoginType  VARCHAR(MAX),
	RoleName  VARCHAR(MAX)
	
)

SET @query = "USE [?];

INSERT INTO #tDatabaseRole
SELECT @@SERVERNAME AS ServerName
	    ,DB_NAME() AS DatabaseName	
		,CASE 		
			WHEN DB_NAME() IN ('msdb','master','Admin','tempdb','model') 
			THEN 'SystemDatabase'		
			ELSE 'UserDatabase'	 
		 END AS 'DatabaseType'
	    ,m.name AS LoginName
	    ,m.type_desc AS LoginType
		,r.name AS RoleName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id AND m.type != 'R'
WHERE m.name NOT LIKE '##%'
AND m.name NOT LIKE 'NT %'
ORDER BY r.name, m.name"

EXEC sp_MSforeachdb @query

SELECT a.ServerName
	  ,a.DatabaseName
	  ,a.DatabaseType
	  ,a.LoginName
	  ,a.LoginType
	  ,STUFF((SELECT ', ' + b.RoleName 
			  FROM #tDatabaseRole b
			  WHERE a.LoginName = b.LoginName
			  AND a.DatabaseName = b.DatabaseName
			  FOR XML PATH('')), 1, 2, '') AS 'Roles'
FROM #tDatabaseRole a
INNER JOIN master.sys.server_principals sp ON a.LoginName = sp.name
--WHERE a.DatabaseName NOT IN ('master','tempdb','model','Admin')
--WHERE a.DatabaseName = 'SQLInventory'
WHERE sp.is_disabled = 0
GROUP BY a.ServerName
		,a.DatabaseName
		,a.DatabaseType
		,a.LoginName
		,a.LoginType
ORDER BY DatabaseName;

/*
SELECT DISTINCT ServerName 
	  ,DatabaseName
	  ,DatabaseType
	  ,LoginName
	  ,RoleName 
	  ,LoginType
FROM #tDatabaseRole
ORDER BY DatabaseType, DatabaseName, LoginType, LoginName, RoleName

*/