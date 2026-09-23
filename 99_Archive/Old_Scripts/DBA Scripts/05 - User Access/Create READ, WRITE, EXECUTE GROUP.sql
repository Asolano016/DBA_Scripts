SET QUOTED_IDENTIFIER OFF;

DECLARE @Login VARCHAR(100),
	    @DatabaseName VARCHAR(MAX),
		@READ BIT,
		@READWRITE BIT,
		@READWRITEEXECUTE BIT,
		@SQL NVARCHAR(MAX),
		@LineBreak CHAR(1) = CHAR(13) + CHAR(10),
		@DBCount INT = 1

SET @Login = 'LOGIN_NAME'; --Delegation Group
SET @DatabaseName = 'DATABASE_NAME'

--1 to enable the access
SET @READ = 1;
SET @READWRITE = 0;
SET @READWRITEEXECUTE = 0;

IF OBJECT_ID ('tempdb..#tDatabases') IS NOT NULL
	DROP TABLE #tDatabases

CREATE TABLE #tDatabases(
	Id INT IDENTITY(1,1),
	DatabaseName VARCHAR(255)
)

INSERT INTO #tDatabases
SELECT [name]
FROM sys.databases 
WHERE name = @DatabaseName OR COALESCE(@DatabaseName, '') = ''
AND [name] NOT IN ('master','tempdb','model','msdb','Admin','SSISDB')
AND [name] NOT LIKE '%ReportS%'
AND [state] = 0

IF NOT EXISTS (SELECT [name] FROM sys.server_principals WHERE [name] = @Login)
	SET @SQL = @LineBreak + "USE [master];" + @LineBreak + "CREATE LOGIN [" + @Login + "] FROM WINDOWS WITH DEFAULT_DATABASE=[master];" + @LineBreak
ELSE
BEGIN
	PRINT 'Login already exists.'
	SET @SQL = '--Starting Granting PAR Request--' + @LineBreak
END 

BEGIN
	WHILE (SELECT COUNT(DatabaseName) FROM #tDatabases) >= @DBCount
	BEGIN
		SET @SQL = @SQL + (SELECT @LineBreak + "USE [" + DatabaseName +"];" + @LineBreak FROM #tDatabases WHERE Id = @DBCount)
		SET @SQL = @SQL + "IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = '" + @Login + "')" + @LineBreak
		SET @SQL = @SQL + "BEGIN" + @LineBreak
		SET @SQL = @SQL + "   CREATE USER [" + @Login + "] FOR LOGIN [" + @Login +"];" + @LineBreak
		SET @SQL = @SQL + "   ALTER USER [" + @Login + "] WITH DEFAULT_SCHEMA=[dbo];" + @LineBreak
		SET @SQL = @SQL + "END" + @LineBreak
	
		IF @READWRITEEXECUTE = 1
			SET @SQL = @SQL + "ALTER ROLE [db_datareader] ADD MEMBER [" + @Login + "];" + @LineBreak + "ALTER ROLE [db_datawriter] ADD MEMBER [" + @Login + "];" + @LineBreak + "GRANT EXECUTE TO [" + @Login + "];" + @LineBreak
		ELSE IF @READWRITE = 1
			SET @SQL = @SQL + "ALTER ROLE [db_datareader] ADD MEMBER [" + @Login + "];" + @LineBreak + "ALTER ROLE [db_datawriter] ADD MEMBER [" + @Login + "];" + @LineBreak
		ELSE IF @READ = 1 
			SET @SQL = @SQL + "ALTER ROLE [db_datareader] ADD MEMBER [" + @Login + "];" + @LineBreak
	
		SET @DBCount = @DBCount +1
	END
END

--PRINT @SQL
EXEC sp_executesql @SQL
GO