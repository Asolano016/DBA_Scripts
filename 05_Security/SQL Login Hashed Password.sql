SELECT name As login_name
	  ,LOGINPROPERTY(name,'PasswordHash') AS login_password
FROM syslogins
WHERE name IN ('kad_admin','kad_user','cdr_user')


SELECT name As login_name
	  ,LOGINPROPERTY(name,'PasswordHash') AS login_password
	  ,'CREATE LOGIN [' + name + '] WITH PASSWORD = 0x' + CONVERT(NVARCHAR(MAX),CONVERT(VARBINARY(MAX), LOGINPROPERTY(name,'PasswordHash')),2) + ' HASHED;' AS login_creation
FROM syslogins
WHERE name IN ('ukm_monitor')

SELECT name AS login_name,
       sid AS login_sid,
       LOGINPROPERTY(name,'PasswordHash') AS login_password,
       'CREATE LOGIN [' + name + '] WITH PASSWORD = 0x' + CONVERT(NVARCHAR(MAX),CONVERT(VARBINARY(MAX), LOGINPROPERTY(name,'PasswordHash')),2) + ' HASHED, SID = 0x' + CONVERT(VARCHAR(MAX), sid, 2) + ';' AS login_creation
FROM sys.syslogins
WHERE name IN ('cxp17emeauser')