DECLARE @recoverModel VARCHAR(250)

SET @recoverModel = 'SIMPLE'

SELECT name,
	   log_reuse_wait_desc,
	   recovery_model_desc,
	   'ALTER DATABASE [' + name + '] SET RECOVERY ' + @recoverModel + ';' AS alter_script
FROM sys.databases
WHERE recovery_model_desc = 'FULL'
AND name NOT IN ('master','model','tempdb','msdb','admin')