-- BACKUP CHECK
-- FULL BACKUPS

select a.name from master.dbo.sysdatabases a 
 WHERE not exists (select b.database_name
                    from msdb.dbo.backupset b 
                   where DATEDIFF(hour, backup_start_date, getdate()) < 24
                     and a.name = b.database_name 
                     and (b.type = 'D' or b.type = 'I' )) 
                     and a.name <> 'tempdb'
					 order by a.name
-- TRAN BACKUPS

select name from master..sysdatabases a
 WHERE status & 8 != 8
   AND not exists (select database_name
                    from msdb..backupset b
                   where DATEDIFF(hour, backup_start_date, getdate()) < 8
                     and a.name = b.database_name
                     and b.type = 'L')
                     and a.name != 'model'
                     and DATEDIFF (hour, a.crdate, getdate()) > 25


-- Extended FULL BACKUPS 

set quoted_identifier off 
go
set nocount on
go

declare @server_name sysname
declare @sql  nvarchar(700)
declare @dbname sysname

set @server_name = (select @@servername)



SET @SQL=('SELECT  B.name as Database_Name, ISNULL(STR(ABS(DATEDIFF(day, GetDate(),
MAX(Backup_finish_date)))),' + "'" + 'NEVER' + "'" + ') as DaysSinceLastBackup,
ISNULL(Convert(char(10), MAX(backup_finish_date), 101),' + "'" + 'NEVER' + "'"+ ')
as LastBackupDate, ' +  "'" + @server_name + "'" + ' as Servername
FROM  ' +  '[' + @server_name + ']'  + '.master.dbo.sysdatabases B
LEFT OUTER JOIN  ' + '[' + @server_name + ']' + '.msdb.dbo.backupset A
ON A.database_name = B.name AND A.type = ' + "'" + 'D' + "'"+ '
GROUP BY B.Name
having ISNULL(STR(ABS(DATEDIFF(day, GetDate(),MAX(Backup_finish_date)))),2)>=2
ORDER BY B.name')

exec sp_executesql @SQL



-- RECOVERY MODE

select name, recovery_model_desc
from sys.databases
WHERE NAME NOT IN ('MASTER', 'MODEL', 'MSDB', 'TEMPDB')
order by 1



-- MIRROR CHECK

SELECT
A.name, 
CASE
    WHEN B.mirroring_state is NULL THEN 'Mirroring not configured'
    ELSE 'Mirroring configured'
END as MirroringState 
FROM
sys.databases A 
INNER JOIN sys.database_mirroring B 
ON A.database_id=B.database_id 
WHERE a.database_id > 4 
ORDER BY A.NAME


select b.name, a.mirroring_state_desc, a.mirroring_role_desc, a.mirroring_role_sequence,
a.mirroring_safety_level_desc, a.mirroring_partner_name,
a.mirroring_partner_instance, a.mirroring_witness_name, a.mirroring_witness_state_desc
from sys.database_mirroring a
inner join sys.sysdatabases b
	on a.database_id = b.dbid
where mirroring_guid is not null


-- LOGINS WITH SA

select substring(loginname,1,25) as login_name, substring(dbname,1,20) as default_dbname,
case isntname when 1 then 'Windows' when 0 then 'SQL Server' end
as login_type,
case sysadmin when 0 then 'No' when 1 then 'Yes' end as sysadmin
from master..syslogins
where sysadmin = 1 -- Remove this line for all users
order by loginname


-- LOG SHIPPING

EXEC SP_HELP_LOG_SHIPPING_MONITOR


-- CLUSTER STATUS

SELECT SERVERPROPERTY('IsClustered') AS CLUSTER_STATUS

select * from sys.sysdatabases
where name not in ('master', 'model', 'msdb', 'tempdb')
order by 1

select @@version


-- CHECK FOR JOBS THAT ARE ENABLED

select a.name, b.start_execution_date, b.stop_execution_date,
CASE WHEN b.next_scheduled_run_date IS NULL
	THEN 'No'
	ELSE 'Yes'
	END AS Scheduled,
b.next_scheduled_run_date,
CASE c.run_status
	WHEN 0 THEN 'Failed'
	WHEN 1 THEN 'Succeeded'
	WHEN 2 THEN 'Retry'
	WHEN 3 THEN 'Canceled'
	WHEN 4 THEN 'In Progress'
END as Run_Status
from msdb..sysjobs a
inner join msdb..sysjobactivity b
	on a.job_id = b.job_id
inner join msdb..sysjobhistory c
	on b.job_history_id = c.instance_id
	and c.step_id = 0
where a.enabled = 1
and b.start_execution_date > (getdate() - 15)
order by a.name








