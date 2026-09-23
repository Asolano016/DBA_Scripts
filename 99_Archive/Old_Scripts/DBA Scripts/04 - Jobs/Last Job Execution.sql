--One Schedule

WITH LastJobRun AS (
    SELECT 
        j.job_id AS JobId,
        j.name AS JobName,
        j.description AS JobDescription,
        j.date_created AS DateCreated,
        j.date_modified AS DateModified,
        CASE j.enabled 
            WHEN 1 THEN 'Yes'
            ELSE 'No'
        END AS JobEnabled,
        jh.step_name AS LastStepName,
        jh.message AS LastStepMessage,
        CASE jh.run_status 
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            ELSE 'Unknown'
        END AS LastRunStatus,
        msdb.dbo.agent_datetime(jh.run_date, jh.run_time) AS LastRunTime,
        ((jh.run_duration / 10000 * 3600) + (jh.run_duration / 100 % 100 * 60) + (jh.run_duration % 100)) AS RunDurationInSeconds,
        ROW_NUMBER() OVER (PARTITION BY jh.job_id ORDER BY jh.run_date DESC, jh.run_time DESC) AS RowNum,
        s.name AS ScheduleName,
        CASE s.freq_type 
            WHEN 1 THEN 'Once'
            WHEN 4 THEN 'Daily'
            WHEN 8 THEN 'Weekly'
            WHEN 16 THEN 'Monthly'
            WHEN 32 THEN 'Monthly, relative to freq_interval'
            WHEN 64 THEN 'Starts when SQL Server Agent service starts'
            WHEN 128 THEN 'Starts whenever the CPUs become idle'
        END AS Frequency,
        CASE 
            WHEN s.freq_type = 4 THEN 'Every ' + CAST(s.freq_interval AS NVARCHAR(5)) + ' day(s)'
            WHEN s.freq_type = 8 THEN 
                (SELECT STUFF((SELECT ', ' + datename(dw, number) 
                FROM master..spt_values 
                WHERE type = 'P' 
                AND number BETWEEN 0 AND 6 
                AND (number & s.freq_interval) <> 0 
                FOR XML PATH('')), 1, 2, ''))
            ELSE 'N/A'
        END AS Days,
        STUFF(STUFF(RIGHT('000000' + CONVERT(NVARCHAR, s.active_start_time), 6), 5, 0, ':'), 3, 0, ':') AS StartTime,
        (CASE WHEN js.next_run_date > 0 THEN 
            CONVERT(DATETIME, 
                CONVERT(NVARCHAR, js.next_run_date), 
                112) + 
            STUFF(STUFF(RIGHT('000000' + CONVERT(NVARCHAR, js.next_run_time), 6), 5, 0, ':'), 3, 0, ':') 
        END) AS NextRunDateTime
    FROM 
        msdb.dbo.sysjobs j
    INNER JOIN 
        msdb.dbo.sysjobhistory jh ON j.job_id = jh.job_id
    LEFT JOIN
        msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
    LEFT JOIN
        msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
)
SELECT * FROM LastJobRun WHERE RowNum = 1

--Multiples Schedules

WITH LastJobRun AS (
    SELECT 
        j.job_id AS JobId,
        j.name AS JobName,
        j.description AS JobDescription,
        j.date_created AS DateCreated,
        j.date_modified AS DateModified,
        CASE j.enabled 
            WHEN 1 THEN 'Yes'
            ELSE 'No'
        END AS JobEnabled,
        jh.step_name AS LastStepName,
        jh.message AS LastStepMessage,
        CASE jh.run_status 
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            ELSE 'Unknown'
        END AS LastRunStatus,
        msdb.dbo.agent_datetime(jh.run_date, jh.run_time) AS LastRunTime,
        ((jh.run_duration / 10000 * 3600) + (jh.run_duration / 100 % 100 * 60) + (jh.run_duration % 100)) AS RunDurationInSeconds,
        ROW_NUMBER() OVER (PARTITION BY jh.job_id, s.schedule_id ORDER BY jh.run_date DESC, jh.run_time DESC) AS RowNum,
        s.name AS ScheduleName,
        CASE s.freq_type 
            WHEN 1 THEN 'Once'
            WHEN 4 THEN 'Daily'
            WHEN 8 THEN 'Weekly'
            WHEN 16 THEN 'Monthly'
            WHEN 32 THEN 'Monthly, relative to freq_interval'
            WHEN 64 THEN 'Starts when SQL Server Agent service starts'
            WHEN 128 THEN 'Starts whenever the CPUs become idle'
        END AS Frequency,
        CASE 
            WHEN s.freq_type = 4 THEN 'Every ' + CAST(s.freq_interval AS NVARCHAR(5)) + ' day(s)'
            WHEN s.freq_type = 8 THEN 
                (SELECT STUFF((SELECT ', ' + datename(dw, number) 
                FROM master..spt_values 
                WHERE type = 'P' 
                AND number BETWEEN 0 AND 6 
                AND (number & s.freq_interval) <> 0 
                FOR XML PATH('')), 1, 2, ''))
            ELSE 'N/A'
        END AS Days,
        STUFF(STUFF(RIGHT('000000' + CONVERT(NVARCHAR, s.active_start_time), 6), 5, 0, ':'), 3, 0, ':') AS StartTime,
        (CASE WHEN js.next_run_date > 0 THEN 
            CONVERT(DATETIME, 
                CONVERT(NVARCHAR, js.next_run_date), 
                112) + 
            STUFF(STUFF(RIGHT('000000' + CONVERT(NVARCHAR, js.next_run_time), 6), 5, 0, ':'), 3, 0, ':') 
        END) AS NextRunDateTime
    FROM 
        msdb.dbo.sysjobs j
    INNER JOIN 
        msdb.dbo.sysjobhistory jh ON j.job_id = jh.job_id
    LEFT JOIN
        msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
    LEFT JOIN
        msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
)
SELECT * FROM LastJobRun WHERE RowNum = 1;