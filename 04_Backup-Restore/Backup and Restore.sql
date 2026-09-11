

BACKUP DATABASE CCSDB
TO  DISK = N'\\phx-dc.dhl.com\usqas\BS09959\MSSQL_ADMIN\Backup-do-not-delete\CCSDB1.bak',
DISK = N'\\phx-dc.dhl.com\usqas\BS09959\MSSQL_ADMIN\Backup-do-not-delete\CCSDB2.bak',
DISK = N'\\phx-dc.dhl.com\usqas\BS09959\MSSQL_ADMIN\Backup-do-not-delete\CCSDB3.bak',
DISK = N'\\phx-dc.dhl.com\usqas\BS09959\MSSQL_ADMIN\Backup-do-not-delete\CCSDB4.bak'
WITH NOINIT,  NAME = N'CCSDB-Full Database Backup', compression, STATS = 10, COPY_ONLY
GO


restore database CCSDB_BKUP_10252019
from disk = '\\phx-dc.dhl.com\usqas\BS09959\MSSQL_ADMIN\Backup-do-not-delete\CCSDB1.bak', 
disk = '\\phx-dc.dhl.com\usqas\BS09959\MSSQL_ADMIN\Backup-do-not-delete\CCSDB2.bak', 
disk = '\\phx-dc.dhl.com\usqas\BS09959\MSSQL_ADMIN\Backup-do-not-delete\CCSDB3.bak', 
disk = '\\phx-dc.dhl.com\usqas\BS09959\MSSQL_ADMIN\Backup-do-not-delete\CCSDB4.bak' 
with recovery, replace,
move 'CCSDB_BKUP_10252019_Data' to 'F:\SQLDBF_MSSQLSERVER\CCSDB_BKUP_10252019.mdf',
move 'CCSDB_BKUP_10252019_Log' to 'H:\SQLLog_MSSQLSERVERCCSDB_BKUP_10252019_1.ldf'

go
	


--
-- when DB is in Restoring state, the following command get the db online
--
RESTORE DATABASE GBS_Procurement_2_CD_031419 WITH RECOVERY
GO

restore FILELISTONLY from disk = 'H:\SAT_Backups\backup\Backup_INC26880280\SAT_AR_TEST.bak' 



SEND A NOTE TO THE TEAM Y THERE IS ANY ADDITIONAL  INFORMATION OR SENT
THE STEPS I TOOK.



declare @numDays int;
declare @DBName varchar(50);
	
	-- check backup for the last 7 days;
set @numDays = 30;
set @DBName = 'cis_dbStatistics'
set @DBName = 'msdb,'+'model,'+'master,'+'Admin'
SELECT  
   CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
   msdb.dbo.backupset.database_name,  
   msdb.dbo.backupset.backup_start_date,  
   msdb.dbo.backupset.backup_finish_date,
   DATEDIFF(mi, msdb.dbo.backupset.backup_start_date,msdb.dbo.backupset.backup_finish_date) as MinutesToComplete,
   CASE msdb..backupset.type  
       WHEN 'D' THEN 'Database'  
       WHEN 'L' THEN 'Log'  
       WHEN 'I' THEN 'Incr'  
   END AS backup_type,  
   convert (bigint, backup_size / 1048576 ) sizeInMB,
   msdb.dbo.backupmediafamily.physical_device_name
FROM   msdb.dbo.backupmediafamily  
   INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id  
WHERE  (CONVERT(datetime, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - @numDays)  
 and msdb.dbo.backupset.database_name not in ('msdb','model','master','Admin')
--and msdb.dbo.backupset.database_name in (@DBName)
And msdb..backupset.type = 'D'
ORDER BY  
   msdb.dbo.backupset.database_name, 
   msdb.dbo.backupset.backup_finish_date desc
