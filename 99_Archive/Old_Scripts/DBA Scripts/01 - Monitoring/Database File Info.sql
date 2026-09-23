SELECT d.name AS 'DatabaseName'
	  ,mf.name AS 'LogicalFileName'
	  ,SUBSTRING(mf.physical_name, LEN(mf.physical_name) - (CHARINDEX('\', REVERSE(mf.physical_name), 0) - 2), LEN(mf.physical_name)) AS 'PhysicalFileName'
	  ,REVERSE(SUBSTRING(REVERSE(mf.physical_name), CHARINDEX('\', REVERSE(mf.physical_name), 0), LEN(mf.physical_name))) AS 'PhysicalFilePath'
FROM sys.master_files mf
INNER JOIN sys.databases d ON d.database_id = mf.database_id
WHERE d.name NOT IN ('tempdb','master','msdb','model','Admin')
ORDER BY DatabaseName