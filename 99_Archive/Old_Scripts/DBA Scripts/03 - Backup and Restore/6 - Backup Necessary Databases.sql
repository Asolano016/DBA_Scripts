SET QUOTED_IDENTIFIER OFF;

DECLARE @name VARCHAR(50) -- database name 
DECLARE @path VARCHAR(256) -- path for backup files 
DECLARE @fileName VARCHAR(256) -- filename for backup 
DECLARE @fileDate VARCHAR(20) -- used for file name 

SET @path = "C:\Backups\" 

SELECT @fileDate = CONVERT(VARCHAR(20),GETDATE(),112)  + "_" + CONVERT(VARCHAR(20),DATEPART(HH, GETDATE())) + CONVERT(VARCHAR(20),DATEPART(MI, GETDATE()))

DECLARE db_cursor CURSOR FOR 
SELECT name 
FROM MASTER.dbo.sysdatabases 
--WHERE name IN ("master","msdb") --Add only the database that needs a backup

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @name  

WHILE @@FETCH_STATUS = 0  
BEGIN  
      SET @fileName = @path + @name + "_" + @fileDate + ".bak" 
      
    BACKUP DATABASE @name 
    TO DISK = @fileName
    WITH COMPRESSION, COPY_ONLY
    --SELECT @fileName
      FETCH NEXT FROM db_cursor INTO @name 
END 

CLOSE db_cursor  
DEALLOCATE db_cursor

