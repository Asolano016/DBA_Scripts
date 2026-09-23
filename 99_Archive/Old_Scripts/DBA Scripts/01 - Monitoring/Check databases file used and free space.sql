DECLARE @command VARCHAR(MAX)

DECLARE @DBInfo TABLE (
	ServerName VARCHAR(100),   
	DatabaseName VARCHAR(100),
	FileName VARCHAR(100),   
	PhysicalFileName NVARCHAR(520),   
	FileSizeMB DECIMAL(10,2),   
	MaxSizeMB DECIMAL(10,2),   
	SpaceUsedMB DECIMAL(10,2),   
	FreeSpaceMB DECIMAL(10,2), 
	FreeSpacePct varchar(8) 
) 

DECLARE @DBSize TABLE ( 
	ServerName VARCHAR(100),   
	DatabaseName VARCHAR(100),
	DatabaseSizeMB DECIMAL(10,2) 
) 

SELECT @command = 'Use [' + '?' + '] SELECT   
@@servername as ServerName,   
' + '''' + '?' + '''' + ' AS DatabaseName   , name, filename 
    , convert(decimal(12,2),round(a.size/128.000,2)) as FileSizeMB 
	, convert(decimal(12,2),round(a.maxsize/128.000,2)) as MaxSizeMB 
    , convert(decimal(12,2),round(fileproperty(a.name,'+''''+'SpaceUsed'+''''+')/128.000,2)) as SpaceUsedMB 
    , convert(decimal(12,2),round((a.size-fileproperty(a.name,'+''''+'SpaceUsed'+''''+'))/128.000,2)) as FreeSpaceMB, 
    CAST(100 * (CAST (((a.size/128.0 -CAST(FILEPROPERTY(a.name,' + '''' + 'SpaceUsed' + '''' + ' ) AS int)/128.0)/(a.size/128.0)) AS decimal(4,2))) AS varchar(8)) + ' + '''' + '%' + '''' + ' AS FreeSpacePct 
FROM dbo.sysfiles a' 

INSERT INTO @DBInfo 
EXEC sp_MSForEachDB @command   

INSERT INTO @DBSize
SELECT ServerName
	  ,DatabaseName
	  ,(SELECT FileSizeMB FROM @DBInfo m WHERE PhysicalFileName LIKE '%.mdf' AND d.DatabaseName = m.DatabaseName)
	  + (SELECT FileSizeMB FROM @DBInfo l WHERE PhysicalFileName LIKE '%.ldf' AND d.DatabaseName = l.DatabaseName) AS DatabaseSizeMB
FROM @DBInfo d
WHERE DatabaseName NOT IN ('Admin','master','msdb','model','tempdb')
GROUP BY ServerName, DatabaseName

SELECT ServerName
	  ,DatabaseName
	  ,FileName
	  ,PhysicalFileName
	  ,FileSizeMB
	  ,CAST(FileSizeMB / 1024 AS DECIMAL(10,2)) AS 'FileSizeGB' 
	  ,MaxSizeMB
	  ,SpaceUsedMB
	  ,FreeSpaceMB
	  ,FreeSpacePct
FROM @DBInfo 
WHERE DatabaseName NOT IN ('Admin','master','msdb','model','tempdb')
--AND PhysicalFileName LIKE '%.ldf'
ORDER BY DatabaseName

--SELECT ServerName
--	  ,DatabaseName
--    ,CAST(DatabaseSizeMB / 1024 AS DECIMAL(10,2)) AS 'DatabaseSizeGB'
--    ,CAST((DatabaseSizeMB / 1024)/1024 AS DECIMAL(10,2)) AS 'DatabaseSizeTB'
--FROM @DBSize
--ORDER BY DatabaseSizeMB DESC

