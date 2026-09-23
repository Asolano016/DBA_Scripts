SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#tDatabaseRole') IS NOT NULL
DROP TABLE #tDatabaseRole

DECLARE @query NVARCHAR(MAX),
		@val NVARCHAR(MAX);

CREATE TABLE #tDatabaseRole(
	ServerName VARCHAR(MAX),
	DatabaseName VARCHAR(MAX),
	DatabaseType VARCHAR(MAX),
	LoginName  VARCHAR(MAX),
	RoleName  VARCHAR(MAX),
	LoginType  VARCHAR(MAX)
)

SET @query = "USE [?];

			  --IF '?' NOT IN ('master','tempdb','model','Admin')
			  INSERT INTO #tDatabaseRole
			  SELECT @@SERVERNAME AS ServerName
			  	    ,DB_NAME() AS DatabaseName
					,CASE 
						WHEN DB_NAME() IN ('msdb','master','Admin','tempdb','model') THEN 'SystemDatabase'
						ELSE 'UserDatabase'
					 END AS 'DatabaseType'
			  	    ,m.name AS LoginName
			  	    ,r.name AS RoleName
			  	    ,m.type_desc AS LoginType
			  FROM sys.database_role_members rm
			  JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
			  JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id AND m.type != 'R'
			  WHERE m.name NOT LIKE '##%'
		      AND m.name NOT LIKE 'NT %'
			  AND m.name IN ('PRG-DC\UDLDHL-CL-EXP-APP-SUPPORT')
			  ORDER BY r.name, m.name
			  --END"

EXEC sp_MSforeachdb @query

SELECT a.ServerName
	  ,a.DatabaseName
	  ,a.DatabaseType
	  ,a.LoginName
	  ,STUFF((SELECT ', ' + b.RoleName 
			  FROM #tDatabaseRole b
			  WHERE a.LoginName = b.LoginName
			  AND a.DatabaseName = b.DatabaseName
			  FOR XML PATH('')), 1, 2, '') AS 'Roles'
	  ,a.LoginType
FROM #tDatabaseRole a
GROUP BY a.ServerName
		,a.DatabaseName
		,a.DatabaseType
		,a.LoginName
		,a.LoginType
ORDER BY DatabaseName;

DROP TABLE #tDatabaseRole