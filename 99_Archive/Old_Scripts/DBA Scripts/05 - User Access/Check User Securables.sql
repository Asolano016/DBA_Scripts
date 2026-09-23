USE DATABASE_NAME
GO

DECLARE @loginName VARCHAR(50),
	    @objectName VARCHAR(50)

SET @loginName = 'SalesSupport'
SET @objectName = 'sp_DCManagementForm'


SELECT @@SERVERNAME AS server_name
	  ,DB_NAME() AS database_name
      ,d.name AS login_name
	  ,d.type_desc
	  ,class_desc
	  ,permission_name
	  ,state_desc
	  ,o.name AS object_name
	  ,o.type_desc
	  --,o.create_date AS object_create_date
	  --,o.modify_date AS object_modify_date
	  --,d.create_date AS login_create_date
	  --,d.modify_date AS login_modify_date
FROM sys.database_principals d
INNER JOIN sys.database_permissions p ON p.grantee_principal_id = d.principal_id
INNER JOIN sys.objects o ON o.object_id = p.major_id OR o.object_id = p.minor_id
INNER JOIN sys.schemas s on s.schema_id = o.schema_id
WHERE d.name = @loginName
AND o.name = @objectName
--WHERE d.principal_id NOT BETWEEN 0 AND 4
ORDER BY d.name, o.name

