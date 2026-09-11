-- Role Name
DECLARE @RoleName VARCHAR(25) = 'ParagonReportingRole';

-- Check Role Membership

SELECT 
    r.name AS RoleName,
    m.name AS MemberName
FROM 
    sys.database_role_members rm
    JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
    JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
WHERE 
    r.name = @RoleName;

	-- Check Role Permissions:
SELECT 
    dp.class_desc,
    dp.permission_name,
    dp.state_desc,
    OBJECT_NAME(dp.major_id) AS object_name
FROM 
    sys.database_permissions dp
    JOIN sys.database_principals p ON dp.grantee_principal_id = p.principal_id
WHERE 
    p.name = @RoleName;

-- Check Schema Permissions
SELECT 
    schema_name = s.name,
    role_name = p.name,
    permission_name = dp.permission_name,
    state_desc = dp.state_desc
FROM 
    sys.database_permissions dp
    JOIN sys.schemas s ON dp.major_id = s.schema_id
    JOIN sys.database_principals p ON dp.grantee_principal_id = p.principal_id
WHERE 
    p.name = @RoleName;