-- SCRIPT OUT SERVER PERMISSIONS


-- Role Members 

SELECT  
       usr2.name as RoleMemberships,
	   usr1.name as ServerRole
FROM    sys.server_principals AS usr1 
        INNER JOIN sys.server_role_members AS rm ON usr1.principal_id = rm.role_principal_id 
        INNER JOIN sys.server_principals AS usr2 ON rm.member_principal_id = usr2.principal_id 
where (usr2.name  not like ('NT SERVICE%'))
	AND (usr2.name  not like ('NT AUTHORITY%'))
	AND (usr2.name not in ('PRG-DC\U-DLG-PRGDC-SQL_Admins', 'KUL-DC\GDLKULDC-CBJDBA', 'KUL-DC\UDLMYKUL-QUALYS'))
	AND (usr2.name  not like ('%UDLDHL%_TAR%'))
--order by usr1.name desc, usr2.name
order by usr2.name, usr1.name desc


-- Permissions 

SELECT  server_principals.name,
		server_permissions.permission_name,
		server_permissions.state_desc      
FROM    sys.server_permissions AS server_permissions WITH ( NOLOCK ) 
        INNER JOIN sys.server_principals AS server_principals WITH ( NOLOCK ) ON server_permissions.grantee_principal_id = server_principals.principal_id 
WHERE   (server_principals.type IN ( 'S', 'U', 'G' ))
		and (server_permissions.permission_name not in ('CONNECT SQL'))
		and (server_principals.name not like ('##MS_Policy%'))
		and (server_principals.name  not like ('NT AUTHORITY%'))
ORDER BY server_principals.name, 
		server_permissions.permission_name,
        server_permissions.state_desc 
      


/********* Permissions by login II **************************************************/

DECLARE @DB_USers TABLE(DBName sysname, UserName sysname, LoginType sysname, AssociatedRole varchar(max))  
INSERT @DB_USers EXEC sp_MSforeachdb  ' use [?] SELECT ''?'' AS DB_Name, case prin.name when ''dbo'' then prin.name + 
'' (''+ (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') + '')'' else prin.name end AS UserName, prin.type_desc AS LoginType, isnull(USER_NAME(mem.role_principal_id),'''') 
AS AssociatedRole  FROM sys.database_principals prin 
LEFT OUTER JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id WHERE prin.sid IS NOT NULL and prin.sid NOT IN (0x00) 
and prin.is_fixed_role <> 1 AND prin.name NOT LIKE ''##%''' SELECT  username,dbname,logintype ,   
STUFF(   (  SELECT ',' + CONVERT(VARCHAR(500),associatedrole)  FROM @DB_USers user2  WHERE  user1.DBName=user2.DBName AND user1.UserName=user2.UserName  FOR XML PATH('')   )   ,1,1,'') AS Permissions_user  
FROM @DB_USers user1 
where username not like ('NT SERVICE%')
GROUP BY  dbname,username ,logintype   
--ORDER BY DBName,username 
ORDER BY username, DBName



