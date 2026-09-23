USE master
GO

SET QUOTED_IDENTIFIER OFF

IF OBJECT_ID('tempdb..#tLoginRole') IS NOT NULL
DROP TABLE #tLoginRole

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
				  ,'LOGINNAME'
				  ,'LOGINNAME')";

CREATE TABLE #tLoginRole(
	ServerName VARCHAR(50),
	LoginName  VARCHAR(50),
	RoleName  VARCHAR(50)
)


INSERT INTO #tLoginRole
SELECT @@SERVERNAME As ServerName
       ,m.name AS LoginName
	   ,r.name AS RoleName
FROM sys.server_role_members rm
INNER JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
INNER JOIN sys.server_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name NOT LIKE '##%'
AND m.name NOT LIKE 'NT %'
AND m.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa')
AND m.type IN ('U','G','S')

UNION ALL

SELECT @@SERVERNAME As ServerName
      ,sp.name AS LoginName
      ,CASE 
		WHEN p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DEFINITION') 
			THEN 'activity monitor'
		WHEN p.permission_name IN ('ALTER TRACE') 
			THEN 'alter trace'
		ELSE NULL
	   END AS RoleName
FROM sys.server_principals sp
INNER JOIN sys.server_permissions p ON p.grantee_principal_id = sp.principal_id AND p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DEFINITION','ALTER TRACE')
WHERE sp.name NOT LIKE '##%'
AND sp.name NOT LIKE 'NT %'
AND sp.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa')
AND sp.type IN ('U','G','S')
GROUP BY sp.name, CASE 
					WHEN p.permission_name IN ('VIEW SERVER STATE','VIEW ANY DEFINITION') 
						THEN 'activity monitor'
					WHEN p.permission_name IN ('ALTER TRACE') 
						THEN 'alter trace'
					ELSE NULL
				   END 

SET @query = "SELECT ServerName
			  	    ,LoginName
			  	    ,RoleName
			  	    ,'Instance-Level Role' AS RoleType
			  FROM #tLoginRole
			  WHERE LoginName NOT IN " + @LoginName + "
			  ORDER BY LoginName, RoleName"

EXEC sp_executesql @query

DROP TABLE #tLoginRole