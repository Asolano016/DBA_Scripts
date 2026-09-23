SELECT CASE 
								WHEN InstanceName LIKE '%\%' THEN UPPER(REPLACE(InstanceName,'\','-'))
								ELSE UPPER(InstanceName) + '-DEFAULT'
							 END  AS InstanceConnection 
	     
FROM tBackupDirInfoProd
ORDER BY Domain, InstanceId