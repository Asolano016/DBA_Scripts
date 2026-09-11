SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#tDatabaseRole') IS NOT NULL
DROP TABLE #tDatabaseRole;

DECLARE @query NVARCHAR(MAX);

CREATE TABLE #tDatabaseRole(
	ServerName VARCHAR(MAX),
	DatabaseName VARCHAR(MAX),
	DatabaseType VARCHAR(MAX),
	LoginName  VARCHAR(MAX),
	RoleName  VARCHAR(MAX),
	LoginType  VARCHAR(MAX)
);

SET @query = "USE '';

			  --IF '' NOT IN ('master','tempdb','model','Admin')
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
			  AND m.name NOT IN ('KUL-DCUDLMYKUL-QUALYS','PRG-DCU-DLG-PRGDC-SQL_Admins','PRG-DCUDLDHL-SQLmigdist','sa','dbo')
			  ORDER BY r.name, m.name
			  --END"

EXEC sp_MSforeachdb @query;

SELECT DISTINCT ServerName 
	  --,DatabaseName
	  --,DatabaseType
	  ,LoginName
	  ,RoleName 
	  ,LoginType
FROM #tDatabaseRole
ORDER BY DatabaseType, DatabaseName, LoginType, LoginName, RoleName

SELECT DISTINCT ServerName 
	  ,LoginName
	  ,STUFF((SELECT DISTINCT ', ' + d2.RoleName
	    FROM #tDatabaseRole d2
		WHERE d2.LoginName = d1.LoginName
		ORDER BY ', ' + d2.RoleName
		FOR XML PATH('') ), 1, 1, '')  AS Roles 
	  ,LoginType
FROM #tDatabaseRole d1
ORDER BY LoginType, LoginName, Roles

DROP TABLE #tDatabaseRole

