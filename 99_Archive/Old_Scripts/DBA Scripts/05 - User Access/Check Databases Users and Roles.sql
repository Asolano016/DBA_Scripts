USE DatabaseName
GO

SELECT @@SERVERNAME AS ServerName
	  ,DB_NAME() AS DatabaseName
	  ,m.name AS LoginName
	  ,r.name AS RoleName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
WHERE m.name != 'dbo'
--AND m.name LIKE '%USERNAME%'
ORDER BY m.name, r.name
GO