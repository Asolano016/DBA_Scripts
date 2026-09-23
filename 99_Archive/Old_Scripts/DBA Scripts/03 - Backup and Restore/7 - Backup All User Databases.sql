--**--**--**--**--**--Backup All User Databases--**--**--**--**--**--

USE master
GO

SET QUOTED_IDENTIFIER OFF

DECLARE @bak NVARCHAR(MAX);

SET @bak = "USE [?];

			IF '?' NOT IN ('master','msdb','tempdb','model','Admin','SSISDB')
			BEGIN
				BACKUP DATABASE ?
				TO  DISK = N'E:\Backups\SQL_TEST_DELL_JP\?.bak'
				WITH NOINIT,  NAME = N'?-Full Database Backup', COMPRESSION, STATS = 10
			END"

EXEC sp_MSforeachdb @bak