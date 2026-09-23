SELECT ml.LogID
	  ,m.Name AS MonitoringName
	  ,ms.ServerName
	  ,i.InstanceName
	  ,ml.Date
	  ,ml.StatusID
	  ,ml.Duration
FROM [dbo].[tMonitoringLog] ml
INNER JOIN [dbo].[tMonitoringServer] ms ON ms.ServerId = ml.ServerId
INNER JOIN [dbo].[tInstances] i ON i.ID = ml.InstanceId
INNER JOIN [dbo].[tMonitoring] m ON m.MonitoringId = ml.MonitoringId
WHERE ml.MonitoringID = 1065
ORDER BY ml.Date DESC