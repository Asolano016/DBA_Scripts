
-- Disable
SELECT name AS JobName
      ,'EXEC msdb.dbo.sp_update_job @job_name = ''' + name + ''', @enabled = 0;' AS DisableScript
FROM msdb.dbo.sysjobs
WHERE name NOT LIKE '_DHL_%'
AND enabled = 1
AND name NOT IN ('sysjobhistory_purge'
				 ,'syspolicy_purge_history'
				 ,'SSIS Server Maintenance Job') 

-- Enable 
SELECT name AS JobName
	  ,'EXEC msdb.dbo.sp_update_job @job_name = ''' + name + ''', @enabled = 1;' AS EnableScript
FROM msdb.dbo.sysjobs
WHERE name NOT LIKE '_DHL_%'
AND enabled = 0
AND name NOT IN ('sysjobhistory_purge'
				 ,'syspolicy_purge_history'
				 ,'SSIS Server Maintenance Job') 