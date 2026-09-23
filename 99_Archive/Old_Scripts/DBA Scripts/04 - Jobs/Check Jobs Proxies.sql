
USE msdb
GO

SELECT DISTINCT j.job_id, CASE sc.enabled
			WHEN 1 THEN 'Enabled'
			WHEN 0 THEN'Disabled'
			ELSE 'No Scheduled'
	   END schedule
INTO #tScheduleTemp
FROM sysjobs j
LEFT JOIN sysjobschedules ss ON ss.job_id = j.job_id
LEFT JOIN sysschedules sc ON sc.schedule_id = ss.schedule_id
WHERE j.name NOT LIKE '%_DHL%'

SELECT DISTINCT @@SERVERNAME AS sever_name
	  ,j.name AS job_name
	  ,s.step_name
	  ,s.subsystem
	  ,p.name AS proxy_name
	  ,c.name AS credential_name
	  ,c.credential_identity
	  ,schedule
	  ,CASE s.last_run_outcome
		WHEN 0 THEN 'Failed'
		WHEN 1 THEN 'Succeeded'
		WHEN 2 THEN 'Retry'
		WHEN 3 THEN 'Canceled'
	    ELSE 'Unknown'
	   END last_run_outcome
	  ,CASE
			WHEN js.last_run_date = 0 THEN CAST('No Execution Registered' AS VARCHAR(25))
			ELSE CAST(LEFT(CAST(js.last_run_date AS VARCHAR(30)),4) +'-'+ LEFT(RIGHT(CAST(js.last_run_date AS VARCHAR(30)),4),2)  +'-'+ RIGHT(CAST(js.last_run_date AS VARCHAR(30)),2) + ' ' +
				 STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(js.last_run_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':') AS VARCHAR(20))
		END last_run_date
FROM sysjobs j
INNER JOIN sysjobsteps s ON s.job_id = j.job_id
INNER JOIN sysproxies p ON p.proxy_id = s.proxy_id
INNER JOIN sys.credentials c ON c.credential_id = p.credential_id
INNER JOIN sysjobservers js ON js.job_id = j.job_id
INNER JOIN #tScheduleTemp t ON t.job_id = j.job_id
WHERE j.enabled = 1
ORDER BY j.name

DROP TABLE #tScheduleTemp