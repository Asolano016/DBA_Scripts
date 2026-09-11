
/*
.SYNOPSIS
    PAR STANDARD REQUEST PROCESS
.DESCRIPTION
	Generate the sql statements required to grant the access based on the PAR request contents. Only STANDARD PAR REQUESTS.
	How can you use it?
		Once you change values in the PARAMETER SECTION below, you can connect to the instance, copy this code and paste into a query windows.
		Change the Results to Text (Ctrl+T or Tools > Options > Query Results > Results To Text). 
		Then, when you run the code you will get in the output window the list of sql statments required to
		grant the priveleges to the user in the instance you are connected to.
		Then, you can copy and paste the output into a new query windows and execute it.
		
.NOTES
	Author  : William Jimenez
    Version : 1.00 - 11.14.2018 - Initial version
    Vervion : 1.01 - 01.16.2019 - Handle SQL Version 2008.
    Version : 1.04 - 04.24.2019 - @USERName variable length changed from 50 to 150
    Version : 1.05 - 07.17.2019 - Handle SQL accounts
    							  Use one string variable to grant the access on databases.
	
*/
DECLARE 
	@DBName VARCHAR(50),
	@USERName VARCHAR(150),
	@WINDOWSUser VARCHAR(1),
	@CreateSQLUser VARCHAR(1),
	@SQLUserPwd VARCHAR(100),
	@CrLf varchar(10),
	@Apost varchar(10),
	@BULK varchar(1),
	@CRE varchar(1),
	@OWNER varchar(1),
	@READER varchar(1),
	@DTS varchar(1),
	@AGE varchar(1),
	@vVersion smallint,
	@SQL VARCHAR(max),
	@DBsSQL VARCHAR(max);

	
-- **********************************************************
--
--  	PARAMETERS SECTION
--
--	Provide the user name (Only AD account. It does not work for MS SQL Accounts)
--  Change to Y the parameter you wan to use.
-- **********************************************************
	

SET @USERName 	= 'PRG-DC\UDLDHL-DGFTRHJSERVER' -- provide the user name
SET @OWNER		= 'Y'	-- GRANT db_owner
SET @CRE		= 'Y'	-- GRANT dbcreator
SET @BULK		= 'Y'	-- GRANT bulkadmin
SET @READER 	= 'N'	-- GRANT db_datareader
SET @AGE 		= 'N'	-- GRANT SQLAgentOperatorRole, SQLAgentReaderRole, SQLAgentUserRole 
SET @DTS 		= 'N'	-- GRANT db_ssisadmin
SET @SQL 		= ''	-- INITIAL VALUE
SET @DBsSQL 	= ''	-- INITIAL VALUE
SET @WINDOWSUser	= 'Y'
SET @CreateSQLUser  = 'N'
SET @SQLUserPwd = ''

-- the code starts, do not change any line

set @CrLf  = char(10) -- linefeed
set @Apost = char(39) -- Apostrophe
-- identify SQL version
select @vVersion = 2012 where @@VERSION like '%201%';
select @vVersion = 2008 where @@VERSION like '%2008%';


 IF @WINDOWSUser = 'Y' 
   BEGIN
     If not Exists (select loginname from master.dbo.syslogins where name = @USERName )
	 BEGIN
		SET @SQL = @SQL + 'USE [master]'+@CrLf+';'+@CrLf
		SET @SQL = @SQL + 'CREATE LOGIN ['+@USERName+'] FROM WINDOWS WITH DEFAULT_DATABASE=[master]'+@CrLf+';'+@CrLf
	
	 END;
   END;

IF @CreateSQLUser = 'Y'
  BEGIN
   SET @SQL = @SQL + 'USE [master]'+@CrLf+';'+@CrLf
   SET @SQL = @SQL + 'CREATE LOGIN ['+@USERName+'] WITH PASSWORD='+@Apost+@SQLUserPwd+@Apost+', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF'+@CrLf+';'+@CrLf
  END;

IF @BULK = 'Y'
  BEGIN 
	SET @SQL = @SQL + 'USE [master]'+@CrLf+';'+@CrLf
	IF (@vVersion >= 2012)
		SET @SQL = @SQL + 'ALTER SERVER ROLE [bulkadmin] ADD MEMBER ['+@USERName+']'+@CrLf+';'+@CrLf
	ELSE
		SET @SQL = @SQL + 'EXEC master..sp_addsrvrolemember @loginame = ['+@USERName+'], @rolename = '+@Apost+'bulkadmin'+@Apost+@CrLf+';'+@CrLf
  END;

IF @CRE = 'Y'
  BEGIN 
	SET @SQL = @SQL + 'USE [master]'+@CrLf+';'+@CrLf
	IF (@vVersion >= 2012)
		SET @SQL = @SQL + 'ALTER SERVER ROLE [dbcreator] ADD MEMBER ['+@USERName+']'+@CrLf+';'+@CrLf
	ELSE
		SET @SQL = @SQL + 'EXEC master..sp_addsrvrolemember @loginame = ['+@USERName+'], @rolename = '+ @Apost+ 'dbcreator'+@Apost+@CrLf+';'+@CrLf
  END;
  
  
IF (@DTS = 'Y') OR (@AGE = 'Y')
  BEGIN 
	SET @SQL = @SQL + 'USE [msdb]'+@CrLf+';'+@CrLf
	SET @SQL = @SQL + 'IF NOT EXISTS (SELECT name FROM [sys].[database_principals] WHERE name = '+@Apost+@USERName+@Apost+')'+@CrLf
	SET @SQL = @SQL + 'CREATE USER ['+@USERName+'] FOR LOGIN ['+ @USERName+']'+@CrLf+ ';'+@CrLf
  END;
  
  
IF @DTS = 'Y'
  BEGIN 
	SET @SQL = @SQL + 'USE [msdb]'+@CrLf+';'+@CrLf
	IF (@vVersion >= 2012)
		SET @SQL = @SQL + 'ALTER ROLE [db_ssisadmin] ADD MEMBER ['+@USERName+']'+@CrLf+';'+@CrLf
	ELSE
		SET @SQL = @SQL + 'EXEC sp_addrolemember '+@Apost+'db_ssisadmin'+@Apost+','+@Apost+@USERName+@Apost+@CrLf+';'+@CrLf
  END;


IF @AGE = 'Y'
  BEGIN 
	SET @SQL = @SQL + 'USE [msdb]'+@CrLf+';'+@CrLf
	IF (@vVersion >= 2012)
		SET @SQL = @SQL + 'ALTER ROLE [SQLAgentOperatorRole] ADD MEMBER ['+@USERName+']'+@CrLf+';'+@CrLf
	ELSE
		SET @SQL = @SQL + 'EXEC sp_addrolemember '+@Apost+'SQLAgentOperatorRole'+@Apost+','+@Apost+@USERName+@Apost+@CrLf+';'+@CrLf
	SET @SQL = @SQL + 'USE [msdb]'+@CrLf+';'+@CrLf
	IF (@vVersion >= 2012)
		SET @SQL = @SQL + 'ALTER ROLE [SQLAgentReaderRole] ADD MEMBER ['+@USERName+']'+@CrLf+';'+@CrLf
	ELSE
		SET @SQL = @SQL + 'EXEC sp_addrolemember '+@Apost+'SQLAgentReaderRole'+@Apost+','+@Apost+@USERName+@Apost+@CrLf+';'+@CrLf
	SET @SQL = @SQL + 'USE [msdb]'+@CrLf+';'+@CrLf
	IF (@vVersion >= 2012)
		SET @SQL = @SQL + 'ALTER ROLE [SQLAgentUserRole] ADD MEMBER ['+@USERName+']'+@CrLf+';'+@CrLf
	ELSE
		SET @SQL = @SQL + 'EXEC sp_addrolemember '+@Apost+'SQLAgentUserRole'+@Apost+','+@Apost+@USERName+@Apost+@CrLf+';'+@CrLf
  END;
  
IF (@READER = 'Y') OR (@OWNER  = 'Y')
BEGIN 
	DECLARE curDBs CURSOR FAST_FORWARD FOR
		select name 
		from sys.databases
		where name not in ('master','tempdb','model','msdb','Admin');
  
	OPEN curDBs

	FETCH NEXT FROM curDBs   INTO @DBName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		SET @DbsSQL = @DbsSQL + 'USE ['+@DBName+']'+@CrLf+';'+@CrLf
		SET @DbsSQL = @DbsSQL + 'IF NOT EXISTS (SELECT name FROM [sys].[database_principals] WHERE name = '+@Apost+@USERName+@Apost+')'+@CrLf
		SET @DbsSQL = @DbsSQL + 'CREATE USER ['+@USERName+'] FOR LOGIN ['+ @USERName+']'+@CrLf+ ';'+@CrLf
				
		IF @READER = 'Y'  
			IF (@vVersion >= 2012)
				SET @DbsSQL = @DbsSQL + 'ALTER ROLE [db_datareader] ADD MEMBER ['+@USERName+']'+@CrLf+ ';'+@CrLf;
			ELSE
				SET @DbsSQL = @DbsSQL + 'EXEC sp_addrolemember '+@Apost+'db_datareader'+@Apost+','+@Apost+@USERName+@Apost+@CrLf+';'+@CrLf

		IF @OWNER  = 'Y'  
			IF (@vVersion >= 2012)
			  BEGIN
				SET @DbsSQL = @DbsSQL + 'ALTER USER ['+@USERName+'] WITH DEFAULT_SCHEMA=[dbo]'+@CrLf+ ';'+@CrLf;
				SET @DbsSQL = @DbsSQL + 'ALTER ROLE [db_owner] ADD MEMBER ['+@USERName+']'+@CrLf+ ';'+@CrLf;				
			  END 
			ELSE
				SET @DbsSQL = @DbsSQL + 'EXEC sp_addrolemember '+@Apost+'db_owner'+@Apost+','+@Apost+@USERName+@Apost+@CrLf+';'+@CrLf
		FETCH NEXT FROM curDBs INTO @DBName
	END 
	CLOSE curDBs 
	DEALLOCATE curDBs

END;
EXEC (@SQL)
 --PRINT (@SQL)
 --print (@DBsSQL)
 --IF (@READER = 'Y') OR (@OWNER  = 'Y') 
EXEC (@DBsSQL) ;
GO
