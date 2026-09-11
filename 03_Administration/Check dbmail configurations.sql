SELECT @@SERVERNAME AS instance_name
	  ,p.name AS profile_name
	  ,a.name AS account_name
	  ,p.description AS profile_description
	  ,a.description AS account_description
	  ,a.email_address
	  ,s.servertype AS server_type
	  ,s.servername AS server_name
	  ,s.port
FROM msdb.dbo.sysmail_profile p
INNER JOIN msdb.dbo.sysmail_profileaccount pa ON pa.profile_id = p.profile_id
INNER JOIN msdb.dbo.sysmail_account a ON a.account_id = pa.account_id
INNER JOIN msdb.dbo.sysmail_server s ON s.account_id = a.account_id
ORDER BY a.account_id