SET QUOTED_IDENTIFIER OFF
GO

DECLARE @sharedFolder NVARCHAR(MAX) = '\\Usqaswspc000213\ctask5672271\'
--DECLARE @dataPath NVARCHAR(MAX) = '\\Usqaswspc000213\ctask5672271'
--DECLARE @logPath NVARCHAR(MAX) = '\\Usqaswspc000213\ctask5672271'

SELECT
    d.[name] AS DatabaseName,
    CAST(SUM(mf.[size]) * 8.0 / 1024 AS DECIMAL(18,2)) AS SizeMB,
    CAST(SUM(mf.[size]) * 8.0 / 1024 / 1024 AS DECIMAL(18,2)) AS SizeGB,
    "BACKUP DATABASE [" + d.[name] + "] TO  DISK = N'" + @sharedFolder + d.[name] + ".bak' WITH  COPY_ONLY, NOFORMAT, NOINIT,  NAME = N'" + d.[name] + "-Full Database Backup', SKIP, NOREWIND, NOUNLOAD, COMPRESSION,  STATS = 10" AS BackupScript,
    "RESTORE DATABASE [" + d.[name] + "] FROM  DISK = N'" + @sharedFolder + d.[name] + ".bak' WITH  FILE = 1,  NOUNLOAD,  REPLACE,  STATS = 5"
FROM sys.master_files mf
INNER JOIN sys.databases d ON mf.[database_id] = d.[database_id]
WHERE d.[name] IN ('API_ARCA'
,'Cic'
,'CRA_PAISES'
,'DHLParams'
,'ExpoSimple'
,'FactDC'
,'FactSQL'
,'Origenregional_Ar'
,'RBS'
,'ReportServer'
,'ReportServerTempDB'
,'SanHist'
,'SAP')
GROUP BY d.[name]
ORDER BY SizeGB DESC;


