USE msdb
GO

-- Create a Database Mail account  
EXECUTE msdb.dbo.sysmail_add_account_sp  
    @account_name = 'ACCOUNT_NAME',  
    @description = 'ACCOUNT_DESCRIPTION.',  
    @email_address = 'email@dhl.com',  
    @replyto_address = 'email@dhl.com',  
    @display_name = 'DISPLAY_NAME',  
    @mailserver_name = 'gateway.dhl.com' ;  
  
-- Create a Database Mail profile  
EXECUTE msdb.dbo.sysmail_add_profile_sp  
    @profile_name = 'PROFILE_NAME',  
    @description = 'PROFILE_DESCRIPTION' ;  
  
-- Add the account to the profile  
--EXECUTE msdb.dbo.sysmail_add_profileaccount_sp  
--    @profile_name = 'PROFILE_NAME',  
--    @account_name = 'ACCOUNT_NAME',  
--    @sequence_number =1 ;  
  
-- Grant access to the profile to the DBMailUsers role  
--EXECUTE msdb.dbo.sysmail_add_principalprofile_sp  
--    @profile_name = 'AdventureWorks Administrator Profile',  
--    @principal_name = 'ApplicationUser',  
--    @is_default = 1 ;  

--Service Owner Martina Spackova approval.
--Profile : PROFILE_NAME
--Account Name : ACCOUNT_NAME
--Description : DESCRIPTION
--E-mail address : email@dhl.com
--Display Name : DISPLAY_NAME
--reply email : noreply@dhl.com
