------------------JOB SCHEDULES------------------


USE msdb
GO

------------------DECLARE TABLE VARIABLES------------------

DECLARE @stgJobsSchedules TABLE(
	ServerName NVARCHAR(256) NULL,
	JobId NVARCHAR(85) NULL,
	ScheduleId INT NULL,
	JobName NVARCHAR(256) NULL,
	ScheduleName NVARCHAR(256) NULL,
	Enabled INT NULL,
	FreqType INT NULL,
	FreqInterval INT NULL,
	FreqSubdayType INT NULL,
	FreqSubdayInterval INT NULL,
	FreqRelativeType INT NULL,
	FreqRecurrenceFactor INT NULL,
	ActiveStartTime INT NULL,
	ActiveEndTime INT NULL,
	NextRunDate DATETIME NULL,
	DateCreated DATETIME NULL,
	DateModified DATETIME NULL
)

DECLARE @JobsSchedules TABLE(
	ServerName NVARCHAR(256) NULL,
	JobId NVARCHAR(85) NULL,
	ScheduleId INT NULL,
	JobName NVARCHAR(256) NULL,
	ScheduleName NVARCHAR(256) NULL,
	[Enabled] INT NULL,
	Occurrence VARCHAR(100) NULL,
	Frequency VARCHAR(100) NULL,
	NextRunDate DATETIME NULL,
	DateCreated DATETIME NULL,
	DateModified DATETIME NULL
)


------------------EXTRACT DATA------------------

INSERT INTO @stgJobsSchedules
SELECT @@SERVERNAME AS ServerName
	  ,j.job_id AS JobId
	  ,js.schedule_id As ScheduleId
	  ,j.[name] AS JobName
	  ,s.[name] AS ScheduleName
	  ,s.[enabled] AS ScheduleEnabled
	  ,s.freq_type AS FreqType
	  ,s.freq_interval AS FreqInterval
	  ,s.freq_subday_type AS FreqSubdayType
	  ,s.freq_subday_interval AS FreqSubdayInterval
	  ,s.freq_relative_interval AS FreqRelativeType
	  ,s.freq_recurrence_factor AS FreqRecurrenceFactor
	  ,s.active_start_time AS ActiveStartTime
	  ,s.active_end_time AS ActiveEndTime
	  ,CASE js.next_run_date
		WHEN 0
			THEN NULL
		ELSE CONVERT(DATETIME, CONVERT(CHAR(8), js.next_run_date, 112) + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), js.next_run_time), 6), 5, 0, ':'), 3, 0, ':'))
	   END NextRunDate
	  ,s.date_created AS DateCreated
	  ,s.date_modified AS DateModified
FROM sysjobs j
INNER JOIN sysjobschedules js ON js.job_id = j.job_id
INNER JOIN sysschedules s ON s.schedule_id = js.schedule_id
WHERE j.enabled = 1
AND s.enabled = 1

------------------TRANSFORM AND LOAD DATA------------------

INSERT INTO @JobsSchedules
SELECT ServerName
	  ,JobId
	  ,ScheduleId
	  ,JobName
	  ,ScheduleName
	  ,[Enabled]
	  ,CASE FreqType
		WHEN 1 
			THEN 'Unused'
		WHEN 4 
			THEN 'Every ' + CONVERT(VARCHAR, FreqInterval) + ' day(s)'
		WHEN 8 
			THEN 'Every ' + CONVERT(VARCHAR, FreqRecurrenceFactor) + ' weeks(s) on ' + 
				  LEFT(CASE 
						WHEN FreqInterval & 1 = 1 THEN 'Sunday, '
						ELSE ''
					   END + 
					   CASE 
						WHEN FreqInterval & 2 = 2 THEN 'Monday, '
						ELSE ''
					   END + 
					   CASE 
						WHEN FreqInterval & 4 = 4 THEN 'Tuesday, '
						ELSE ''
					   END + 
					   CASE 
						WHEN FreqInterval & 8 = 8 THEN 'Wednesday, '
						ELSE ''
						END + 
					   CASE 
						WHEN FreqInterval & 16 = 16 THEN 'Thursday, '
						ELSE ''
					   END + 
					   CASE 
						WHEN FreqInterval & 32 = 32 THEN 'Friday, '
						ELSE ''
					   END + 
					   CASE 
						WHEN FreqInterval & 64 = 64 THEN 'Saturday, '
						ELSE ''
					  END, 
				      LEN(CASE 
						   WHEN FreqInterval & 1 = 1 THEN 'Sunday, '
						   ELSE ''
						  END + 
						  CASE 
						   WHEN FreqInterval & 2 = 2 THEN 'Monday, '
						   ELSE ''
						  END + 
						  CASE 
						   WHEN FreqInterval & 4 = 4 THEN 'Tuesday, '
						   ELSE ''
						  END +
						  CASE 
						   WHEN FreqInterval & 8 = 8 THEN 'Wednesday, '
						   ELSE ''
						  END + 
						  CASE 
						   WHEN FreqInterval & 16 = 16 THEN 'Thursday, '
						   ELSE ''
						  END + 
						  CASE 
						   WHEN FreqInterval & 32 = 32 THEN 'Friday, '
						   ELSE ''
						  END + 
						  CASE 
						   WHEN FreqInterval & 64 = 64 THEN 'Saturday, '
						   ELSE ''
						  END) - 1)
	    WHEN 16 THEN 'Day ' + CONVERT(VARCHAR, FreqInterval) + ' of every ' + CONVERT(VARCHAR, FreqRecurrenceFactor) + ' month(s)'
	    WHEN 32 THEN 'The ' + 
	  CASE FreqRelativeType
	    WHEN 1 THEN 'First'
	    WHEN 2 THEN 'Second'
	    WHEN 4 THEN 'Third'
	    WHEN 8 THEN 'Fourth'
	    WHEN 16 THEN 'Last'
	   END + 
	   CASE FreqInterval
	    WHEN 1 THEN ' Sunday'
	    WHEN 2 THEN ' Monday'
	    WHEN 3 THEN ' Tuesday'
	    WHEN 4 THEN ' Wednesday'
	    WHEN 5 THEN ' Thursday'
	    WHEN 6 THEN ' Friday'
	    WHEN 7 THEN ' Saturday'
	    WHEN 8 THEN ' Day'
	    WHEN 9 THEN ' Weekday'
	    WHEN 10 THEN ' Weekend Day'
	   END + ' of every ' + CONVERT(VARCHAR, FreqRecurrenceFactor) + ' month(s)'
		ELSE NULL
	   END AS Occurence
	  ,CASE FreqSubdayType
		WHEN 1
			THEN 'Occurs once at ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), ActiveStartTime), 6), 5, 0, ':'), 3, 0, ':')
		WHEN 2
			THEN 'Occurs every ' + CONVERT(VARCHAR, FreqSubdayInterval) + ' Seconds(s) between ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), ActiveStartTime), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), ActiveEndTime), 6), 5, 0, ':'), 3, 0, ':')
		WHEN 4
			THEN 'Occurs every ' + CONVERT(VARCHAR, FreqSubdayInterval) + ' Minute(s) between ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), ActiveStartTime), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), ActiveEndTime), 6), 5, 0, ':'), 3, 0, ':')
		WHEN 8
			THEN 'Occurs every ' + CONVERT(VARCHAR, FreqSubdayInterval) + ' Hour(s) between ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), ActiveStartTime), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), ActiveEndTime), 6), 5, 0, ':'), 3, 0, ':')
		ELSE NULL
	   END AS Frequency
	  ,NextRunDate
	  ,DateCreated
	  ,DateModified
FROM @stgJobsSchedules
ORDER BY NextRunDate DESC

------------------SELECT DATA------------------

SELECT ServerName
	  ,JobId 
	  ,ScheduleId
	  ,JobName 
	  ,ScheduleName
	  ,[Enabled] 
	  ,Occurrence 
	  ,Frequency 
	  ,NextRunDate 
	  ,DateCreated 
	  ,DateModified 
FROM  @JobsSchedules