-- ScriptID ScriptName
-- 1123		PARAudit.ps1
-- 1126		PARGrant.ps1
-- 1128		PARApproval.ps1
-- 1127		DACSParAudit.ps1
-- 1146		DataCollector2.ps1
-- 1165		TARApproval.ps1
-- 1166		TARGrantRevoke.ps1
-- 1169		GenAIDBA.ps1
-- 1173		SIAHeartbeat.ps1
-- 1210		TARActions.ps1
-- 1211		Maintenance.ps1
-- SELECT * FROM [dbo].[tScript]

DECLARE @ScriptId INT = 1126

SELECT * 
FROM [dbo].[tScriptLog]
WHERE [ScriptId] = @ScriptId
AND [Text] LIKE '%GS_PHXAMHGDEV%'

----------------------------------------------------

SELECT sl.[ScriptLogID]
      --,sl.[ScriptID]
	  ,s.[ScriptName]
      --,sl.[ModuleID]
	  --,sm.[Name] AS [ModuleName]
      --,sl.[HostID]
	  ,h.[HostName]
      --,sl.[InstanceID]
	  ,UPPER(i.[InstanceName]) AS [InstanceName]
	  --,sl.[TaskID]
	  ,slt.[TaskName]
      --,sl.[TypeID]
	  ,CASE 
			WHEN sl.[TypeID]= 0 THEN 'INFORMATION'
			WHEN sl.[TypeID]= 1 THEN 'SUCCESS'
			WHEN sl.[TypeID]= 2 THEN 'WARNING'
			WHEN sl.[TypeID]= 3 THEN 'ERROR'
			WHEN sl.[TypeID]= 4 THEN 'QUERY'
	   END [TypeName]
      ,sl.[Text]
      ,sl.[Error]
      ,sl.[RunningON]
      ,sl.[Command]
	  ,sl.[CreateDate]
FROM [dbo].[tScriptLog] sl
INNER JOIN [dbo].[tScript] s ON s.[ScriptID] = sl.[ScriptID]
INNER JOIN [dbo].[tInstances] i ON i.[ID] = sl.[InstanceID]
INNER JOIN [dbo].[tHosts] h ON h.[HostID] = sl.[HostID]
INNER JOIN [dbo].[tScriptModule] sm ON sm.[ModuleID] = sl.[ModuleID]
INNER JOIN [dbo].[tScriptLogTask] slt ON slt.[TaskID] = sl.[TaskID]
WHERE sl.ScriptID = @ScriptId
AND sl.[CreateDate] BETWEEN '2026-07-14 15:30:00' AND '2026-07-14 16:00:00'