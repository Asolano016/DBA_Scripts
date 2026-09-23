Update tMonitoringList set Date = '2022-04-26 00:00:00'
where MonitoringID = 1044
and InstanceID in (SELECT i.ID
FROM [dbo].[tMonitoringList] ml
INNER JOIN [dbo].[tInstances] i ON i.ID = ml.InstanceID
WHERE MonitoringID = 1044
AND i.InProduction IN (2,10,8,14,13)
AND ml.Status = 1)
--AND i.Domain = 'phx-dc.dhl.com') 


SELECT * FROM tMonitoringList 
WHERE MonitoringID = 1044
and InstanceID in (SELECT i.ID
FROM [dbo].[tMonitoringList] ml
INNER JOIN [dbo].[tInstances] i ON i.ID = ml.InstanceID
WHERE MonitoringID = 1044
AND i.InProduction IN (2,10,8,14,13)
AND ml.Status = 1) 
ORDER BY Date DESC

--DACS PAR Audit

SELECT *FROM [dbo].[tMonitoringHosts]
WHERE MonitoringID = 1065

UPDATE [dbo].[tMonitoringHosts]
SET Date = '2024-03-22 14:55:00'
WHERE MonitoringID = 1065