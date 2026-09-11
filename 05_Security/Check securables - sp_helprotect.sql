--https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-helprotect-transact-sql?view=sql-server-ver15

USE DatabaseName
GO

--Check Securables

EXEC sp_helprotect @name = 'ObjectName'
			      ,@username  = 'dummy'