SET QUOTED_IDENTIFIER OFF
GO

IF OBJECT_ID('tempdb..#tUserRole') IS NOT NULL
DROP TABLE #tUserRole

DECLARE @loginName VARCHAR(MAX),
		@query NVARCHAR(MAX);

SET @loginName = "('LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME'
				  ,'LOGINNAME')";

CREATE TABLE #tUserRole(
	ServerName VARCHAR(50),
	DatabaseName VARCHAR(50),
	LoginName  VARCHAR(50),
	RoleName  VARCHAR(50),
	DropRole VARCHAR(MAX)
)

SET @query = "USE [?];

				INSERT INTO #tUserRole
				SELECT @@SERVERNAME AS ServerName
					  ,DB_NAME() AS DatabaseName
					  ,m.name AS LoginName
					  ,r.name AS RoleName
					  ,'USE [?]; ALTER ROLE [' + r.name + '] DROP MEMBER [' + m.name + '];'
				FROM sys.database_role_members rm
				JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
				JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
				WHERE m.name != 'dbo'
				AND m.name IN " + @loginName + "
				--AND r.name IN ('db_owner') --Check for specific roles
				ORDER BY r.name, m.name"

EXEC sp_MSforeachdb @query

SELECT * FROM #tUserRole
--WHERE RoleName = 'db_datareader'

SELECT DISTINCT ServerName 
	  ,DatabaseName
	  ,LoginName
	  ,STUFF((SELECT DISTINCT ', ' + d2.RoleName
	    FROM #tUserRole d2
		WHERE d2.LoginName = d1.LoginName
		ORDER BY ', ' + d2.RoleName
		FOR XML PATH('') ), 1, 1, '')  AS Roles
	  --,DropRole
FROM #tUserRole d1
ORDER BY LoginName, Roles

DROP TABLE #tUserRole

 