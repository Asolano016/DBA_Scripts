SELECT ID
	  ,InstanceName
	  ,TcpPort
	  ,CASE 
			WHEN InstanceName LIKE '%\%' THEN REPLACE(InstanceName, '\', '.' + Domain + '\') + ', ' + TcpPort
			ELSE InstanceName + '.' + Domain + ', ' + TcpPort
	   END InstanceConn
FROM tInstances
WHERE InProduction IN (2, 8)
AND Domain = 'phx-dc.dhl.com'