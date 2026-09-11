SET QUOTED_IDENTIFIER OFF;

DECLARE @Login VARCHAR(100),
		@ADLogin VARCHAR(100),
	    @SQLLogin VARCHAR(100),
		@SQLLoginPassword NVARCHAR(100),
		@OWN BIT,
		@CRE BIT,
		@BULK BIT,
		@READ BIT,
		@WRI BIT,
		@EXE BIT,
		@AGE BIT,
		@SSIS BIT,
		@SYSA BIT,
		@SECA BIT,
		@PRCA BIT,
		@ALTT BIT,
		@ACMO BIT,
		@SQL NVARCHAR(MAX),
		@LineBreak CHAR(1) = CHAR(13) + CHAR(10),
		@DBCount INT = 1

SET @Login = 'LOGIN_NAME'; --Delegation Group, Service Account or SQL Login name
SET @SQLLoginPassword = ''; --SQL Login Password, only use while creating the password
--1 to enable the access
SET @OWN  = 0;
SET @CRE  = 0;
SET @BULK = 0;
SET @READ = 0;
SET @WRI  = 0;
SET @EXE  = 0;
SET @AGE  = 0;
SET @SSIS = 0;
SET @SYSA = 0;
SET @SECA = 0;
SET @PRCA = 0;
SET @ALTT = 0;
SET @ACMO = 0;

IF OBJECT_ID ('tempdb..#tDatabases') IS NOT NULL
	DROP TABLE #tDatabases

CREATE TABLE #tDatabases(
	Id INT IDENTITY(1,1),
	DatabaseName VARCHAR(255)
)

INSERT INTO #tDatabases
SELECT [name]
FROM sys.databases 
WHERE [name] NOT IN ('master','tempdb','msdb','Admin','SSISDB')
AND [name] NOT LIKE '%ReportS%'
AND [state] = 0

--If don't exists create user.
IF @Login LIKE '%\%'
BEGIN
	IF NOT EXISTS (SELECT [name] FROM sys.server_principals WHERE [name] = @Login)
		SET @SQL = @LineBreak + "USE [master];" + @LineBreak + "CREATE LOGIN [" + @Login + "] FROM WINDOWS WITH DEFAULT_DATABASE=[master];" + @LineBreak
    ELSE
	BEGIN
		PRINT 'Login already exists.'
		SET @SQL = '--Starting Granting PAR Request--' + @LineBreak
	END 

END
ELSE 
BEGIN
	IF NOT EXISTS (SELECT [name] FROM sys.server_principals WHERE [name] = @Login)
		SET @SQL = @LineBreak + "USE [master];" + "CREATE LOGIN [" + @Login + "] WITH PASSWORD='" + @SQLLoginPassword + "', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON;"  + @LineBreak
	ELSE
	BEGIN
		PRINT 'Login already exists.'
		SET @SQL = '--Starting Granting PAR Request--' + @LineBreak
	END 
END

--Grant sysadmin
IF @SYSA = 1
	SET @SQL = @SQL + "ALTER SERVER ROLE [sysadmin] ADD MEMBER [" + @Login + "];" + @LineBreak
ELSE
BEGIN
	--Grant dbcreator
	IF @CRE = 1
		SET @SQL = @SQL + "ALTER SERVER ROLE [dbcreator] ADD MEMBER [" + @Login + "];" + @LineBreak

	--Grant bulkadmin
	IF @BULK = 1
		SET @SQL = @SQL + "ALTER SERVER ROLE [bulkadmin] ADD MEMBER [" + @Login + "];" + @LineBreak

	--Grant securityadmin
	IF @SECA = 1
		SET @SQL = @SQL + "ALTER SERVER ROLE [securityadmin] ADD MEMBER [" + @Login + "];" + @LineBreak

	--Grant processadmin
	IF @PRCA = 1
		SET @SQL = @SQL + "ALTER SERVER ROLE [processadmin] ADD MEMBER [" + @Login + "];" + @LineBreak
	
	--Grant trace
	IF @ALTT = 1
		SET @SQL = @SQL + "GRANT ALTER TRACE TO [" + @Login + "];" + @LineBreak

	--Grant activity monitor
	IF @ACMO = 1
		SET @SQL = @SQL + "GRANT VIEW ANY DATABASE TO [" + @Login + "];" + @LineBreak + "GRANT VIEW SERVER STATE TO [" + @Login + "];" + @LineBreak

	--Grant SQLAgentOperatorRole
	IF @AGE = 1
	BEGIN
		SET @SQL = @SQL + @LineBreak + "USE [msdb];" + @LineBreak
		SET @SQL = @SQL + "IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = '" + @Login + "')" + @LineBreak
		SET @SQL = @SQL + "CREATE USER [" + @Login + "] FOR LOGIN [" + @Login +"];" + @LineBreak
		SET @SQL = @SQL + "ALTER ROLE [SQLAgentOperatorRole] ADD MEMBER [" + @Login + "];" + @LineBreak
	END
	
	--Grant ssisadmin and db_sssiadmin
	IF @SSIS = 1
	BEGIN
		SET @SQL = @SQL + @LineBreak + "USE [msdb];" + @LineBreak
		SET @SQL = @SQL + "IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = '" + @Login + "')" + @LineBreak
		SET @SQL = @SQL + "BEGIN" + @LineBreak
		SET @SQL = @SQL + "CREATE USER [" + @Login + "] FOR LOGIN [" + @Login +"];" + @LineBreak
		SET @SQL = @SQL + "ALTER USER [" + @Login + "] WITH DEFAULT_SCHEMA=[dbo];" + @LineBreak
		SET @SQL = @SQL + "END" + @LineBreak
		SET @SQL = @SQL + "ALTER ROLE [db_ssisadmin] ADD MEMBER [" + @Login + "];" + @LineBreak
		IF EXISTS (SELECT [name] FROM sys.databases WHERE [name] = 'SSISDB')
		BEGIN
			SET @SQL = @SQL + @LineBreak + "USE [SSISDB];" + @LineBreak
			SET @SQL = @SQL + "IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = '" + @Login + "')" + @LineBreak
			SET @SQL = @SQL + "BEGIN" + @LineBreak
			SET @SQL = @SQL + "CREATE USER [" + @Login + "] FOR LOGIN [" + @Login +"];" + @LineBreak
			SET @SQL = @SQL + "ALTER USER [" + @Login + "] WITH DEFAULT_SCHEMA=[dbo];" + @LineBreak
			SET @SQL = @SQL + "END" + @LineBreak
			SET @SQL = @SQL + "ALTER ROLE [ssis_admin] ADD MEMBER [" + @Login + "];" + @LineBreak
		END
	END
	--Grant db_owner, db_datareader and db_datawriter
	IF @OWN = 1 OR @READ = 1 OR  @WRI = 1 OR @EXE = 1
	BEGIN
		WHILE (SELECT COUNT(DatabaseName) FROM #tDatabases) >= @DBCount
		BEGIN
			SET @SQL = @SQL + (SELECT @LineBreak + "USE [" + DatabaseName +"];" + @LineBreak FROM #tDatabases WHERE Id = @DBCount)
			SET @SQL = @SQL + "IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = '" + @Login + "')" + @LineBreak
			SET @SQL = @SQL + "BEGIN" + @LineBreak
			SET @SQL = @SQL + "CREATE USER [" + @Login + "] FOR LOGIN [" + @Login +"];" + @LineBreak
			SET @SQL = @SQL + "ALTER USER [" + @Login + "] WITH DEFAULT_SCHEMA=[dbo];" + @LineBreak
			SET @SQL = @SQL + "END" + @LineBreak
	
				IF ((@OWN = 1 AND @READ = 1 AND @WRI = 1 AND @EXE = 1) 
				OR (@OWN = 1 AND @READ = 1 AND @WRI = 1) 
				OR (@OWN = 1 AND @READ = 1 AND @EXE = 1) 
				OR (@OWN = 1 AND @EXE = 1 AND @WRI = 1) 
				OR (@OWN = 1 AND @READ = 1) 
				OR (@OWN = 1 AND @WRI = 1) 
				OR (@OWN = 1 AND @EXE = 1) 
				OR (@OWN = 1 ))
					SET @SQL = @SQL + "ALTER ROLE [db_owner] ADD MEMBER [" + @Login + "];" + @LineBreak
				ELSE IF @READ = 1 AND @WRI = 1 AND @EXE = 1
					SET @SQL = @SQL + "ALTER ROLE [db_datareader] ADD MEMBER [" + @Login + "];" + @LineBreak + "ALTER ROLE [db_datawriter] ADD MEMBER [" + @Login + "];" + @LineBreak + "GRANT EXECUTE TO [" + @Login + "];" + @LineBreak
				ELSE IF @READ = 1 AND @WRI = 1
					SET @SQL = @SQL + "ALTER ROLE [db_datareader] ADD MEMBER [" + @Login + "];" + @LineBreak + "ALTER ROLE [db_datawriter] ADD MEMBER [" + @Login + "];" + @LineBreak
				ELSE IF @READ = 1 AND @EXE = 1
					SET @SQL = @SQL + "ALTER ROLE [db_datareader] ADD MEMBER [" + @Login + "];" + @LineBreak + "GRANT EXECUTE TO [" + @Login + "];" + @LineBreak
				ELSE IF @EXE = 1 AND @WRI = 1
					SET @SQL = @SQL + "ALTER ROLE [db_datawriter] ADD MEMBER [" + @Login + "];" + @LineBreak + "GRANT EXECUTE TO [" + @Login + "];" + @LineBreak
				ELSE IF @READ = 1 
					SET @SQL = @SQL + "ALTER ROLE [db_datareader] ADD MEMBER [" + @Login + "];" + @LineBreak
				ELSE IF @WRI = 1
					SET @SQL = @SQL + "ALTER ROLE [db_datawriter] ADD MEMBER [" + @Login + "];" + @LineBreak
				ELSE IF @EXE = 1
					SET @SQL = @SQL + "GRANT EXECUTE TO [" + @Login + "];" + @LineBreak
	
			SET @DBCount = @DBCount +1
		END
	END
END

PRINT @SQL
--EXEC sp_executesql @SQL
GO