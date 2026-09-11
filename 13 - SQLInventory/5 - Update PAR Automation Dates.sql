SELECT * FROM [dbo].[tMonitoring]
WHERE MonitoringID IN (1067,1068)

--SELECT * FROM [dbo].[tMonitoringList]

SELECT * FROM [dbo].[tMonitoringHosts]
WHERE MonitoringID IN (1067,1068)


UPDATE [dbo].[tMonitoringHosts]
SET Date = '2023-06-14 16:15:00'
WHERE MonitoringID = 1067

UPDATE [dbo].[tMonitoringHosts]
SET Date = '2023-06-14 16:45:00'
WHERE MonitoringID = 1068

--1067
--1068