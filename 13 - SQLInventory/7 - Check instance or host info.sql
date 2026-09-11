DECLARE @InstanceName VARCHAR(100) = 'USMIAWSA002',
        @HostName     VARCHAR(100) = 'USMIAWSA002'

SELECT i.[ID]
	  ,UPPER(i.[InstanceName]) AS InstanceName
	  ,UPPER(h.[HostName]) AS HostName
	  ,hi.[Status]
	  ,ips.[Description]
	  ,i.[AlwaysON]
	  ,h.[Cluster]
	  ,i.[Authentication]
	  ,i.[Version]
	  ,i.[Domain]
	  ,i.[GsnNumber]
	  ,i.[GsnName]
	  ,s.[ServiceName]
	  ,s.[ServiceOwner]
FROM [dbo].[tInstances] i
INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
INNER JOIN [dbo].[tHosts] h ON h.HostID = hi.HostID
INNER JOIN [dbo].[tInProductionStatus] ips ON ips.InProduction = i.InProduction
INNER JOIN [dbo].[tInstanceServices] tis ON tis.InstanceID = i.ID
INNER JOIN [dbo].[tServices] s ON s.ServiceID = tis.ServiceID
WHERE (@InstanceName IS NULL OR @InstanceName = '' OR i.InstanceName = @InstanceName)
AND (@HostName IS NULL OR @HostName = '' OR h.HostName = @HostName)
AND AlwaysON = 1