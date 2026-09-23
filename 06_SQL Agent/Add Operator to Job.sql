USE msdb
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @jobName SYSNAME
DECLARE @operatorName SYSNAME

SET @jobName = ''
SET @operatorName = ''

SELECT "EXEC msdb.dbo.sp_update_job " + CHAR(13) +
	   "@job_name = N'"+ name +"'," + CHAR(13) +
	   "@notify_level_email=2," + CHAR(13) +
	   "@notify_level_page=2," + CHAR(13) +
	   "@notify_email_operator_name=N'" + @operatorName + "'" + CHAR(13) AS 'AddOperatorScript'
FROM sysjobs
WHERE name = @jobName


---------------------REPORT---------------------

SELECT j.name AS JobName
	  ,o.name AS OperatorName
      ,o.email_address AS EmailAddress 
	  ,CASE j.notify_level_email
			WHEN 0 THEN 'Never'
			WHEN 1 THEN 'When the job succeeds'
			WHEN 2 THEN 'When the job fails'
			WHEN 3 THEN 'Whenever the job completes (regardless of the job outcome)'
		    ELSE NULL 
	   END NotifyLevelEmail
FROM sysjobs j
INNER JOIN sysoperators o ON o.id = j.notify_email_operator_id
WHERE j.name = @jobName
ORDER BY j.name
