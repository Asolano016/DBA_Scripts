USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @loginName NVARCHAR(MAX),
        @query NVARCHAR(MAX),
		@qry NVARCHAR(MAX)

IF OBJECT_ID('tempdb..#tInstanceLoginRole') IS NOT NULL
DROP TABLE #tInstanceLoginRole;

IF OBJECT_ID('tempdb..#tInstanceLoginPermission') IS NOT NULL
DROP TABLE #tInstanceLoginPermission;

CREATE TABLE #tInstanceLoginRole(
	ServerName VARCHAR(100),
	LoginName  VARCHAR(250),
	RoleName  VARCHAR(50),
	TypeDesc VARCHAR(50)
)

CREATE TABLE #tInstanceLoginPermission(
	ServerName VARCHAR(100),
	LoginName  VARCHAR(250),
	RoleName  VARCHAR(50),
	TypeDesc VARCHAR(50)
)

INSERT INTO #tInstanceLoginRole
SELECT @@SERVERNAME AS ServerName
       ,m.name AS LoginName
	   ,r.name AS RoleName
	   ,m.type_desc AS TypeDesc
FROM sys.server_role_members rm
INNER JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
INNER JOIN sys.server_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name NOT LIKE '##%'
AND m.name NOT LIKE 'NT %'
AND m.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','sa','PRG-DC\UDLDHL-SQLmigdist')

INSERT INTO #tInstanceLoginPermission
SELECT @@SERVERNAME As ServerName
      ,s.name AS LoginName
	  ,p.permission_name AS RoleName
	  ,s.type_desc AS TypeDesc
FROM sys.server_principals s
INNER JOIN sys.server_permissions p ON p.grantee_principal_id = s.principal_id
WHERE s.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','PRG-DC\UDLDHL-SQLmigdist','sa')
AND s.name NOT LIKE '##%'
AND s.name NOT LIKE 'NT %'
AND s.type <> 'R'-- IN ('U','G','S')
AND p.type <> 'COSQ'

SELECT * 
INTO ##tInstanceLogin 
FROM #tInstanceLoginRole
UNION ALL
SELECT * 
FROM #tInstanceLoginPermission

SELECT *
	  ,'Instance-Level' AS RoleType
FROM ##tInstanceLogin
ORDER BY LoginName, RoleName

SET @qry = "SELECT *
	  		      ,'Instance-Level' AS RoleType
			FROM ##tInstanceLogin
			ORDER BY LoginName, RoleName"

DECLARE @subject VARCHAR(100) = 'Login Instance Roles for ' + @@SERVERNAME,
	    @body VARCHAR(200) = 'This a report for the instance access on server' + @@SERVERNAME + ', please see attachment of the full account list that are not in the PAR.',
		@fileName VARCHAR(100) = @@SERVERNAME + '_InstanceAccess.csv'

EXEC msdb.dbo.sp_send_dbmail @profile_name ='Global_SQLDBA_Profile', 
@recipients = 'andres.solanoalpizar@dhl.com',
@subject = @subject,
@body = @body,
@query = @qry, 
@attach_query_result_as_file = 1,
@query_attachment_filename = @fileName,
@query_result_separator =';',
@query_result_header = 1,
@query_result_width = 32767,
@query_result_no_padding = 1

DROP TABLE #tInstanceLoginRole
DROP TABLE #tInstanceLoginPermission
DROP TABLE ##tInstanceLogin