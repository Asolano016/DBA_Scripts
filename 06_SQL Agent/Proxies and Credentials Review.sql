SET QUOTED_IDENTIFIER OFF

DECLARE @password VARCHAR(100) = 'NEW_PASSWORD' 

SELECT @@SERVERNAME AS [ServerName]
	  ,p.name AS [ProxyName]
	  ,c.name AS [CredentialName]
	  ,c.credential_identity AS [ServiceAccountName]
	  ,"ALTER CREDENTIAL [" + c.name + "] WITH IDENTITY = N'" + c.credential_identity + "', SECRET = N'" + @password + "'" UpdatePassword
FROM msdb.dbo.sysproxies p
INNER JOIN master.sys.credentials c ON c.credential_id = p.credential_id

