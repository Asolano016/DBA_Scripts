What is changing for us?

-	If you need to grant not standard access (sysadmin, securityadmin, serveradmin etc.) on the server in production, the PAR must be created in our database.

Permanent access:
-	The standard approved PAR is necessary, don‘t forget to add it to our Database, you can use Storage procedure sp_ApprovedPAR see example bellow

EXEC [dbo].[sp_ApprovedPAR] 
	@ParID        = 12816,
	@InstanceName = 'czchows3335',
	@LoginName    = 'prg-dc\operator_jsteffen',
	@ServerRole   = 'sysadmin'

Temporary access:
-	For temporary access, you have to insert temporary PAR to our database, temporary PAR ID is 1000. In the future there will be process to get real temporary PAR ID, but it is not in place yet, so please use the temporary one (1000) and don‘t forget to add DateTo.

EXEC [dbo].[sp_ApprovedPAR] 
       @ParID        = 1000,
       @InstanceName = 'czchows3335',
       @LoginName    = 'prg-dc\operator_jsteffen',
       @ServerRole   = 'sysadmin',
       @DueDate      = '2015-08-01 00:00:00'

If you forget to add PAR to our database, or if you do it after the sysadmin will be granted, the automatic email will be generated and the granted access will be removed automatically. So be careful. Especially if you are granting temporary rights for a specific RFC, migration etc.


Update table access

UPDATE [tApprovedPAR]
SET DueDate = '2020-05-20 23:00:00'
WHERE LoginName = 'prg-dc\operator_bstein'
AND InstanceID = 4416