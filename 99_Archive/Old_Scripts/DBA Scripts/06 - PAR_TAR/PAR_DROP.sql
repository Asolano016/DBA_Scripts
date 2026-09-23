--**--**--DROP USER--**--**--

SET QUOTED_IDENTIFIER OFF

DECLARE @sqlCommand NVARCHAR(MAX);
DECLARE @UsrName NVARCHAR(50);

SET @UsrName = 'PRG-DC\SRV_CZCHO-ALTSMP6074'

SET @sqlCommand = "USE ?; IF EXISTS (SELECT name FROM sys.database_principals WHERE name = '" + @UsrName + "')
				   DROP USER [" + @UsrName + "]"

EXEC sp_MSforeachdb @sqlCommand

--**--**--DROP LOGIN--**--**--

SET @sqlCommand = 'DROP LOGIN [' + @UsrName + ']'

EXEC sp_executesql @sqlCommand
GO