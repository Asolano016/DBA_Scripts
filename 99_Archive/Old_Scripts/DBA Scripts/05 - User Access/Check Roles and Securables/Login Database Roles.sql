USE master
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @loginName VARCHAR(MAX),
		@query NVARCHAR(MAX),
		@qry NVARCHAR(MAX)

IF OBJECT_ID('tempdb..##tDatabaseLogin') IS NOT NULL
DROP TABLE ##tDatabaseLogin

CREATE TABLE ##tDatabaseLogin(
	ServerName VARCHAR(50),
	DatabaseName VARCHAR(50),
	LoginName  VARCHAR(50),
	RoleName  VARCHAR(50),
	LoginType VARCHAR(50),
	RoleType VARCHAR(50)
)

SET @query = "USE [?];

			IF '?' NOT IN ('model')
			BEGIN
				INSERT INTO ##tDatabaseLogin
				SELECT @@SERVERNAME AS ServerName
					  ,DB_NAME() AS DatabaseName
					  ,m.name AS LoginName
					  ,r.name AS RoleName
					  ,m.type_desc AS LoginType
					  ,'Database-Level Role' AS RoleType
				FROM sys.database_role_members rm
				JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
				JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
				JOIN sys.server_principals s ON s.sid = m.sid
				WHERE m.name != 'dbo'
				AND m.name NOT LIKE '%MS_%'
				AND m.type IN ('U','G','S')
				AND m.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','PRG-DC\UDLDHL-SQLmigdist','sa')
			END"

EXEC sp_MSforeachdb @query

SELECT * 
FROM ##tDatabaseLogin
ORDER BY LoginName, DatabaseName, RoleName

SET @qry = 'SELECT * 
			FROM ##tDatabaseLogin
			ORDER BY LoginName, DatabaseName, RoleName'

DECLARE @subject VARCHAR(100) = 'Login Database Roles for ' + @@SERVERNAME,
	    @body VARCHAR(200) = 'This a report for the databases access on server' + @@SERVERNAME + ', please see attachment of the full account list that are not in the PAR.',
		@fileName VARCHAR(100) = @@SERVERNAME +'_DatabaseAccess.csv'

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

DROP TABLE ##tDatabaseLogin