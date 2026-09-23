SELECT InstanceName
	   ,TcpPort
	   ,Domain
	   ,CASE 
			WHEN InstanceName LIKE '%\%' THEN REPLACE(InstanceName,'\','.' + Domain + '\') + ',' + TcpPort
			ELSE InstanceName + '.' + Domain + ',' + TcpPort
		END 'FQDN'
FROM tInstances
WHERE AlwaysON = 1
AND InProduction IN (2,8,10)