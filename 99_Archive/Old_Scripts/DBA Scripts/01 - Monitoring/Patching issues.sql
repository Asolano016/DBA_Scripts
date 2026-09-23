SELECT * FROM [dbo].[tPatch]
ORDER BY PatchName
SELECT * FROM [dbo].[tPatchCert]
SELECT * FROM [dbo].[tPatchPreCheck]
SELECT * FROM [dbo].[tPatchStatus]

SELECT i.ID AS InstanceId
	  ,i.InstanceName
	  ,h.HostName
	  ,hi.Status
	  ,h.Cluster
	  ,i.PatchStatusID
	  ,i.PatchDetail
	  ,i.PatchPreCheckID
	  ,i.PatchPreCheckDetail
	  ,i.UpdateDate
FROM [dbo].[tInstances] i
INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
INNER JOIN [dbo].[tHosts] h ON h.HostID = hi.HostID
WHERE i.InProduction IN (2)
AND h.Cluster = 'VERITAS'
AND i.PatchStatusID <> 40
AND hi.Status = 'Running'
ORDER BY InstanceName 


SELECT * FROM [dbo].[tInProductionStatus]

--UPDATE [dbo].[tPatch]
--SET  Path = 'SQL2019\SQLServer2019-KB5040948-x64.exe'
--WHERE PatchID = 64 

SELECT * FROM [dbo].[tPatch]
WHERE PatchID = 64 
