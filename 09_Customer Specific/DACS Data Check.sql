--SELECT * FROM [dbo].[tPARauditMonitoring] 
--WHERE INSTANCE = 'mykulws1982'

SELECT p.SQLINSTANCEID
	  ,p.SERVER
	  ,p.INSTANCE
	  ,p.USERNAME
	  ,p.PRIVILEGE
	  ,p.DT_REPORT
	  ,s.ServiceName
	  ,s.ServiceOwner
FROM [dbo].[tPARauditMonitoringDACS] p
INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceId = p.SQLINSTANCEID
INNER JOIN [dbo].[tServices] s ON s.ServiceId = si.ServiceId
WHERE s.ServiceName = 'AP-VN-DSC-BigC-Hosting'
ORDER BY p.DT_REPORT DESC

SELECT p.SQLINSTANCEID
	  ,p.SERVER
	  ,p.INSTANCE
	  ,p.USERNAME
	  ,p.PRIVILEGE
	  ,p.DT_REPORT
	  ,s.ServiceName
	  ,s.ServiceOwner
FROM [dbo].[tPARauditMonitoringDACS] p
INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceId = p.SQLINSTANCEID
INNER JOIN [dbo].[tServices] s ON s.ServiceId = si.ServiceId
WHERE s.ServiceName = 'AP-VN-DSC-BigC-Hosting'
ORDER BY p.DT_REPORT DESC
