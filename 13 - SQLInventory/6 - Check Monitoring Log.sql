SELECT ml.LogID
	  ,m.MonitoringID
	  ,m.Name
	  ,i.ID
	  ,i.InstanceName
	  ,ml.Date
	  ,mls.Name
	  ,mls.Description
FROM [dbo].[tMonitoringLog] ml
INNER JOIN [dbo].[tMonitoring] m ON m.MonitoringID = ml.MonitoringID
INNER JOIN [dbo].[tInstances] i ON i.ID = ml.InstanceID
INNER JOIN [dbo].[tMonitoringLogStatus] mls ON mls.StatusID = ml.StatusID
WHERE ml.InstanceID = 14303
AND ml.MonitoringID = 1027
AND ml.Date BETWEEN '2023-11-17 00:00:00' AND '2023-11-18 00:00:00'
ORDER BY Date DESC