USE msdb
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @tempJob TABLE(
id INT IDENTITY(1,1),
jobid NVARCHAR(255),
name NVARCHAR(255)
)

INSERT INTO @tempJob
SELECT CAST(job_id AS nvarchar(MAX)) AS job_id
      ,name 
FROM sysjobs
WHERE name LIKE '%test%'
ORDER BY name

--SELECT * FROM @tempJob

DECLARE @counter INT = 1,
	    @scheduleid INT = 1,
        @query NVARCHAR(MAX)

WHILE @counter <= (SELECT COUNT(*) FROM @tempJob)
BEGIN

	SET @query = "--Create schedule for:  " +( SELECT name FROM @tempJob WHERE id = @counter) + "
				  DECLARE @schedule_id int
				  EXEC msdb.dbo.sp_add_jobschedule @job_id=N'" + (SELECT jobid FROM @tempJob WHERE id = @counter) + "', @name=N'OneTimeExecution', 
				  		@enabled=1, 
				  		@freq_type=1, 
				  		@freq_interval=1, 
				  		@freq_subday_type=0, 
				  		@freq_subday_interval=0, 
				  		@freq_relative_interval=0, 
				  		@freq_recurrence_factor=1, 
				  		@active_start_date=20191120, 
				  		@active_end_date=99991231, 
				  		@active_start_time=43000, 
				  		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
				  --select @schedule_id
				  GO
				  "
	PRINT @query

	--EXEC sp_executesql @query

	SET @counter = @counter + 1;
END