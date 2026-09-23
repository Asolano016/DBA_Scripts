--
--
-- Script to generate shrink statments for all databases in the instance. It works for the data files. 'tempdb','model','master','msdb','Admin' databases are excluded.
-- Use the output to execute the shrink command.
-- Author: William Jimenez
-- Date: 6/12/2018
--
-- Parameters to update before run the script. Check parameters section below
-- @minPercentage = 0.000 		0.000% default value. For example if you want to identify a data file to release at least 20% of the space used, you have to change the parameter to 20.000.
-- @chkMountPoint = 1 			1: true check mount point 0: false do not check mountpoint, all mountpoints will be checked for al the data files.
-- @mountPoint    = 'e:\SQLDATA\%' 	mount point to check if @chkMountPoint value is 1. Also, you can set e:\% for all the folders in e:drive.
--
--
DECLARE @SQL NVARCHAR(MAX),
@DBName VARCHAR(50),
@name VARCHAR(100),
@filename VARCHAR(200),
@SizeMB float,
@UsedSpaceMB float, 
@AvailableFreeSpaceMB float,
@minPercentage float,
@mountPoint VARCHAR(500),
@totalSpaceToRelease float,
@CrLf varchar(10),
@chkMountPoint smallint;


-- *************************************************************
--
-- 			PARAMETERS SECTION
--
-- *************************************************************
set @minPercentage 	= 0.000 		-- 0.000%
set @chkMountPoint 	= 1 			-- 1: true check mount point 0: false do not check mountpoint, all mountpoint
set @mountPoint 	= 'e:\%' 	-- mount point to check if @chkMountPoint value is 1. 
--**************************************************************
--
-- 			END PARAMETERS SECTION
--
--**************************************************************


set @CrLf = char(10) -- linefeed

CREATE TABLE #tmpSpaceData(
	[DBName] [nvarchar](128) NULL,
	[name] [sysname] NOT NULL,
	[filename] [nvarchar](260) NOT NULL,
	[SizeMB] [float] NULL,
	[UsedSpaceMB] [float] NULL
)

SELECT @SQL =    
'USE [?] INSERT INTO #tmpSpaceData([DBName],[name],[filename],[SizeMB],[UsedSpaceMB])    
SELECT
db_name(s.database_id),
s.name,
s.physical_name,
(s.size * CONVERT(float,8))/1024,
(CAST(CASE s.type WHEN 2 THEN 0 ELSE CAST(FILEPROPERTY(s.name, ''SpaceUsed'') AS float)* CONVERT(float,8) END AS float))/1024 AS [UsedSpace]
FROM
sys.filegroups AS g
INNER JOIN sys.master_files AS s ON ((s.type = 2 or s.type = 0) and s.database_id = db_id() and (s.drop_lsn IS NULL)) AND (s.data_space_id=g.data_space_id);'

 EXEC sp_MSforeachdb @SQL  

DECLARE curtables CURSOR FAST_FORWARD FOR
	select [DBName],[name],[filename],[SizeMB],[UsedSpaceMB], ([SizeMB]-[UsedSpaceMB])AS [AvailableFreeSpaceMB]
	from #tmpSpaceData as r
	where [DBName] not in ('tempdb','model','master','msdb','Admin')
	and ((@chkMountPoint = 0)or (((@chkMountPoint = 1)) and ([filename] like @mountPoint)))
	and (([SizeMB] - [UsedSpaceMB])/[SizeMB])*100 > @minPercentage
        and floor([SizeMB]-[UsedSpaceMB]) > 0
	order by ([SizeMB]-[UsedSpaceMB]);

 set @totalSpaceToRelease = 0.00
 	
OPEN curtables

FETCH NEXT FROM curtables   INTO @DBName,@name,@filename,@SizeMB,@UsedSpaceMB, @AvailableFreeSpaceMB

WHILE @@FETCH_STATUS = 0
BEGIN
 print '-- '+@DBName +' Space to Release(MB): '+convert(varchar(10),floor(@AvailableFreeSpaceMB))
 print 'USE ['+@DBName+']'+@CrLf+'GO'+@CrLf+'DBCC SHRINKFILE ('+@name+','+convert(varchar(10),floor(@UsedSpaceMB) )+')'+@CrLf+ 'GO'+@CrLf
 set @totalSpaceToRelease = @totalSpaceToRelease +  @AvailableFreeSpaceMB
 FETCH NEXT FROM curtables INTO @DBName,@name,@filename,@SizeMB,@UsedSpaceMB, @AvailableFreeSpaceMB
END 
CLOSE curtables 
DEALLOCATE curtables
print '--Total Space to Release(MB): '+convert(varchar(10),floor(@totalSpaceToRelease))

drop table #tmpSpaceData


