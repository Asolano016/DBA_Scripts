DECLARE @RoleName VARCHAR(100) = 'ROLENAME'

SELECT perm.permission_name
      ,perm.state_desc
      ,obj.name AS object_name
      ,obj.type_desc
FROM sys.database_permissions AS perm
INNER JOIN sys.database_principals AS pr ON perm.grantee_principal_id = pr.principal_id
LEFT JOIN sys.objects AS obj ON perm.major_id = obj.object_id
WHERE  pr.name = @RoleName
ORDER BY permission_name