SELECT ml.InstanceID 
	  ,i.InstanceName
	  --,m.MonitoringID
	  ,m.Name AS MonitoringName
	  ,m.Status AS MonitoringStatus
FROM [dbo].[tMonitoringList] ml
INNER JOIN [dbo].[tMonitoring] m ON m.MonitoringID = ml.MonitoringID
INNER JOIN [dbo].[tInstances] i ON i.ID = ml.InstanceID
WHERE m.MonitoringID = 1044
AND m.Status = 0