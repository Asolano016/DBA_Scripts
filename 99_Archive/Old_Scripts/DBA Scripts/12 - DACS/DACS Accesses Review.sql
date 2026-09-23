DECLARE @SQLINSTANCEID INT,
        @INSTANCE VARCHAR(100)

SELECT @SQLINSTANCEID = ID
      ,@INSTANCE = InstanceName
FROM tInstances
WHERE InstanceName = 'czchows6314'

SELECT @SQLINSTANCEID

SELECT SQLINSTANCEID
         ,SERVER
      ,INSTANCE
      ,USERNAME
         ,PRIVILEGE
         ,DT_REPORT
FROM [Audit].[tPARauditMonitoringDACS]
WHERE SQLINSTANCEID = @SQLINSTANCEID
ORDER BY DT_REPORT DESC;

WITH tPARauditMonitoringCTE AS 
(
       SELECT ID
                   ,SQLINSTANCEID
             ,SERVER
             ,INSTANCE
             ,USERNAME
             ,PRIVILEGE
             ,DT_REPORT
             ,ROW_NUMBER() OVER(PARTITION BY SERVER, INSTANCE, USERNAME, PRIVILEGE ORDER BY DT_REPORT DESC) AS RN
       FROM [dbo].[tPARauditMonitoring]
       --WHERE DT_REPORT > CAST(GETDATE() - 1 AS DATE)
)
SELECT ID
         ,CONVERT(NVARCHAR(10), SQLINSTANCEID) AS SQLINSTANCEID
      ,UPPER(SERVER) AS SERVER
      ,UPPER(INSTANCE) AS INSTANCE
      ,USERNAME
      ,CASE 
              WHEN PRIVILEGE = '' THEN 'Account exists in database with no specific permissions - account not documented in PAR.' 
              ELSE REPLACE(RTRIM(REPLACE(CASE 
                                                                      WHEN PRIVILEGE LIKE '%bulkadmin%' THEN REPLACE(PRIVILEGE,' ','')
                                                                      ELSE PRIVILEGE
                                                           END, CHAR (13)+CHAR (10), ',')),'  ', ' ')
          END AS PRIVILEGE
      ,CONVERT(VARCHAR(25),DT_REPORT,120) AS DT_REPORT
FROM tPARauditMonitoringCTE
WHERE RN = 1
AND SQLINSTANCEID = @SQLINSTANCEID
ORDER BY DT_REPORT DESC;