------------------JOB DATA------------------

USE msdb
GO

------------------DECLARE TABLE VARIABLES------------------
DECLARE @stgJobsData TABLE(
	ServerName NVARCHAR(256) NULL,
	JobId NVARCHAR(85) NULL,
	JobName NVARCHAR(256) NULL,
	Description NVARCHAR(1024) NULL,
	Owner NVARCHAR(256) NULL,
	JobEnabled BIT NULL,
	CategoryName NVARCHAR(256) NULL,
	StepName NVARCHAR(256) NULL,
	Message NVARCHAR(MAX) NULL,
	RunStatus VARCHAR(11) NULL,
	LastRunDuration NVARCHAR(256) NULL,
	LastRunDate INT NULL,
	LastRunTime INT NULL,
	DateCreated DATETIME NULL,
	DateModified DATETIME NULL
)

DECLARE @JobsData TABLE(
	ServerName NVARCHAR(256) NULL,
	JobId NVARCHAR(85) NULL,
	JobName NVARCHAR(256) NULL,
	[Description] NVARCHAR(1024) NULL,
	[Owner] NVARCHAR(256) NULL,
	JobEnabled BIT NULL,
	CategoryName NVARCHAR(256) NULL,
	StepName NVARCHAR(256) NULL,
	[Message] NVARCHAR(MAX) NULL,
	RunStatus VARCHAR(11) NULL,
	LastRunDurationSeconds INT NULL,
	LastRunDuration VARCHAR(20) NULL,
	LastRunDate DATETIME NULL,
	DateCreated DATETIME NULL,
	DateModified DATETIME NULL
)

------------------EXTRACT DATA------------------

INSERT INTO @stgJobsData
SELECT @@SERVERNAME AS ServerName
	  ,j.job_id AS JobId
	  ,j.[name] AS JobName
	  ,j.[description] AS Description
	  ,SUSER_SNAME(j.owner_sid) AS 'Owner'
	  ,j.[enabled] AS [Enabled]
	  ,c.[name] AS CategoryName 
	  ,jh.step_name AS StepName
	  ,jh.message AS [Message]
	  ,CASE jh.run_status
		WHEN 0
			THEN 'Failed'
		WHEN 1
			THEN 'Succeeded'
		WHEN 2
			THEN 'Retry'
		WHEN 3
			THEN 'Canceled'
		WHEN 4
			THEN 'In Progress'
		ELSE NULL
	   END RunStatus
	  ,js.last_run_duration AS LastRunDuration
	  ,js.last_run_date AS LastRunDate
	  ,js.last_run_time AS LastRunTime
	  ,j.date_created AS DateCreated
	  ,j.date_modified AS DateModified
FROM msdb..sysjobs j
--INNER JOIN msdb..sysjobactivity ja ON ja.job_id = j.job_id
INNER JOIN msdb..sysjobhistory jh ON jh.job_id = j.job_id
INNER JOIN msdb..sysjobservers js ON js.job_id = j.job_id
INNER JOIN msdb..syscategories c ON c.category_id = j.category_id
WHERE jh.run_date = (SELECT MAX(jh2.run_date)
				     FROM msdb..sysjobhistory jh2
					 WHERE jh2.job_id = jh.job_id )
AND jh.run_time = (SELECT MAX(jh2.run_time)
				   FROM msdb..sysjobhistory jh2
				   WHERE jh2.job_id = jh.job_id
				   AND jh2.run_date = jh.run_date)
AND jh.instance_id = (SELECT MAX(jh2.instance_id)
				      FROM msdb..sysjobhistory jh2
				      WHERE jh2.job_id = jh.job_id
					  AND jh2.step_id <> 0)
--AND jh.step_id = (SELECT MAX(jh2.step_id)
--				  FROM msdb..sysjobhistory jh2
--				  WHERE jh2.job_id = jh.job_id)
AND jh.step_id <> 0
AND c.[name] <> 'Report Server'
AND j.name NOT IN ('syspolicy_purge_history') 
ORDER BY j.name

------------------TRANSFORM AND LOAD DATA------------------

INSERT INTO @JobsData
SELECT ServerName
	  ,JobId
	  ,JobName
	  ,[Description]
	  ,[Owner]
	  ,JobEnabled
	  ,CategoryName
	  ,StepName
	  ,CAST([Message] AS NVARCHAR(MAX)) AS [Message]
	  ,RunStatus
	  ,CASE
		WHEN LEN(LastRunDuration) < 3
			THEN LastRunDuration
		WHEN LEN(LastRunDuration) = 3
			THEN (CAST(LEFT(LastRunDuration,1) AS INT) * 60) + CAST(RIGHT(LastRunDuration,2) AS INT) 
		WHEN LEN(LastRunDuration) = 4
			THEN (CAST(LEFT(LastRunDuration,2) AS INT) * 60) + CAST(RIGHT(LastRunDuration,2) AS INT) 
		WHEN LEN(LastRunDuration) > 4
			THEN (CAST(LEFT(LastRunDuration, LEN(LastRunDuration) - 4) AS INT) * 3600) + (CAST(LEFT(RIGHT(LastRunDuration,4),2) AS INT) * 60) + CAST(RIGHT(LastRunDuration,2) AS INT) 
		ELSE NULL
	   END AS LastRunDurationSeconds
	  ,CASE 
	   WHEN LEN(LastRunDuration) > 4
	   	THEN CASE 
	   			WHEN LEN(LastRunDuration)  = 5
	   				THEN '0' + SUBSTRING(CAST(LastRunDuration AS VARCHAR(30)),0,LEN(LastRunDuration)-3) + ':' +  LEFT(RIGHT(LastRunDuration,4),2) + ':' + RIGHT(LastRunDuration,2)
	   			ELSE SUBSTRING(CAST(LastRunDuration AS VARCHAR(30)),0,LEN(LastRunDuration)-3) + ':' +  LEFT(RIGHT(LastRunDuration,4),2) + ':' + RIGHT(LastRunDuration,2)
	   		END 
	   WHEN LEN(LastRunDuration) = 4
	   	THEN CASE 
	   			WHEN (RIGHT(LastRunDuration,2) = 00)
	   				THEN '00:' + CAST((LastRunDuration / 100) AS VARCHAR(2)) + ':' + CAST((LastRunDuration % 100) AS VARCHAR(2)) + '0'
	   			WHEN (RIGHT(LastRunDuration,2) IN (01,02,03,04,05,06,07,08,09))
	   				THEN '00:' + CAST((LastRunDuration / 100) AS VARCHAR(2)) + ':0' + CAST((LastRunDuration % 100) AS VARCHAR(2))
	   			ELSE '00:' + CAST((LastRunDuration / 100) AS VARCHAR(2)) + ':' + CAST((LastRunDuration % 100) AS VARCHAR(2))
	   			END
	   WHEN LEN(LastRunDuration) = 3
	   	THEN CASE 
	   			WHEN (RIGHT(LastRunDuration,2) = 00)
	   				THEN '00:0' + CAST((LastRunDuration / 100) AS VARCHAR(2)) + ':' + CAST((LastRunDuration % 100) AS VARCHAR(2)) + '0'
	   			WHEN (RIGHT(LastRunDuration,2) IN (01,02,03,04,05,06,07,08,09))
	   				THEN '00:0' + CAST((LastRunDuration / 100) AS VARCHAR(2)) + ':0' + CAST((LastRunDuration % 100) AS VARCHAR(2))
	   			ELSE '00:0' + CAST((LastRunDuration / 100) AS VARCHAR(2)) + ':' + CAST((LastRunDuration % 100) AS VARCHAR(2))
	   			END
	   WHEN LEN(LastRunDuration) = 2
	   	THEN '00:00:' + CAST(LastRunDuration AS VARCHAR(2))
	   ELSE'00:00:0' + CAST(LastRunDuration AS VARCHAR(2))
	   END AS LastRunDuration
	  ,CAST(LEFT(CAST(LastRunDate AS VARCHAR(30)),4) +'-'+ LEFT(RIGHT(CAST(LastRunDate AS VARCHAR(30)),4),2)  +'-'+ RIGHT(CAST(LastRunDate AS VARCHAR(30)),2) + ' ' +
	   STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(LastRunTime as varchar(6)), 6), 3, 0, ':'), 6, 0, ':') AS DATETIME) AS LastRunDate
	  ,DateCreated
	  ,DateModified
FROM @stgJobsData

------------------SELECT DATA------------------

SELECT ServerName
	  ,JobId
	  ,JobName
	  ,[Description]
	  ,[Owner]
	  ,JobEnabled
	  ,CategoryName
	  ,StepName
	  ,[Message]
	  ,RunStatus
	  ,LastRunDurationSeconds
	  ,LastRunDuration
	  ,LastRunDate
	  ,DateCreated
	  ,DateModified
FROM @JobsData