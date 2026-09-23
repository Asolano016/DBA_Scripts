USE SSISDB
GO

EXEC [catalog].configure_catalog RETENTION_WINDOW, 180

SELECT * FROM [catalog].catalog_properties

	
EXEC [internal].[cleanup_server_retention_window]