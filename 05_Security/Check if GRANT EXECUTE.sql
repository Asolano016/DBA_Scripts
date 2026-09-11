DECLARE @username nvarchar(128) = 'PRG-DC\UDLDHL-RDM-DB-READERS';

SELECT COUNT(*) FROM sys.database_permissions 
    WHERE grantee_principal_id = (SELECT UID FROM sysusers WHERE name = @username) 
        AND class_desc = 'DATABASE'
        AND type='EX' 
        AND permission_name='EXECUTE' 
        AND state = 'G';