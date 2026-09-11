SELECT @@SERVERNAME As ServerName
       ,m.name AS LoginName
	   ,r.name COLLATE SQL_Latin1_General_CP1_CI_AS AS RoleName
	   ,m.type_desc AS LoginType
FROM sys.server_role_members rm
INNER JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
INNER JOIN sys.server_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name NOT LIKE '##%'
AND m.name NOT LIKE 'NT %'
AND m.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','PRG-DC\UDLDHL-SQLmigdist','sa')
AND m.type IN ('U','G','S')

UNION ALL

SELECT @@SERVERNAME As ServerName
      ,sp.name AS LoginName
      ,p.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS AS RoleName
	  ,sp.type_desc AS LoginType
FROM sys.server_principals sp
INNER JOIN sys.server_permissions p ON p.grantee_principal_id = sp.principal_id
WHERE sp.name NOT LIKE '##%'
AND sp.name NOT LIKE 'NT %'
AND sp.name NOT IN ('KUL-DC\UDLMYKUL-QUALYS','PRG-DC\U-DLG-PRGDC-SQL_Admins','PRG-DC\UDLDHL-SQLmigdist','sa')
AND sp.type IN ('U','G','S')
AND p.permission_name != 'CONNECT SQL'
ORDER BY LoginName, RoleName
