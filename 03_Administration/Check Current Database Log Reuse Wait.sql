SELECT [name] AS 'DatabaseName'
	  ,[recovery_model_desc] AS 'Recovery Model'
	  ,[log_reuse_wait_desc] AS 'LogReuseWait' 
FROM sys.databases
WHERE [name] NOT IN ('Admin','master','model','msdb','tempdb')
--AND [name] = 'DBNAME' -- Just to check one database
ORDER BY [name]