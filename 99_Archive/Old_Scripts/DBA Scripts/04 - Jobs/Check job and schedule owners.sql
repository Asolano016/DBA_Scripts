USE msdb
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @newOwner NVARCHAR(100) 
SET @newOwner = 'PHX-DC\admin-rbliss'

SELECT @@SERVERNAME AS ServerName
	  ,j.name AS JobName
      ,SUSER_SNAME(j.owner_sid) AS JobOwner
	  ,s.name AS ScheduleName
	  ,SUSER_SNAME(s.owner_sid) AS ScheduleOwner
	  ,j.enabled AS JobEnabled
	  ,"EXEC msdb.dbo.sp_update_job @job_name = '" + j.name + "',
        @enabled = 1,
		@owner_login_name = '" + @newOwner + "';" AS ChangeJobOwner
	  ,"EXEC msdb.dbo.sp_update_schedule @schedule_id = " + CAST(s.schedule_id AS NVARCHAR(100)) + ",
        @enabled = 1,
		@owner_login_name = '" + @newOwner + "';" AS ChangeScheduleOwner
FROM sysjobs j
INNER JOIN sysjobschedules js ON js.job_id = j.job_id
INNER JOIN sysschedules s ON s.schedule_id = js.schedule_id
WHERE j.name NOT IN ('SSIS Server Maintenance Job','syspolicy_purge_history','_DHL')
--AND SUSER_SNAME(j.owner_sid) = 'USERNAME'
--AND SUSER_SNAME(j.owner_sid) IN ('USERNAME','USERNAME')
--AND SUSER_SNAME(s.owner_sid) <> 'USERNAME'
--AND j.name = 'SHIPT Clean Up'
ORDER BY j.name, s.name