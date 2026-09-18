/******************************************************************************
SHRINK OPPORTUNITY ANALYSIS
-------------------------------------------------------------------------------

PURPOSE

    Estimate the optimal size of SQL Server data and log files while
    preserving sufficient operational free space.

OBJECTIVES

    • Identify reclaimable free space
    • Avoid over-shrinking files
    • Reserve working space for database growth
    • Reserve space for rebuilding the largest index
    • Calculate a safe shrink target

IMPORTANT

    This script DOES NOT perform any shrink operation.

    It only estimates:

        CurrentSizeMB
        UsedSpaceMB
        Recommended Free Space
        Index Rebuild Reserve
        Optimal Size
        Potential Space Recovery

INTERPRETATION

    CurrentSizeUpMB

        Current file size.

    UsedSpaceUpMB

        Space currently used.

    FreeSpaceMB

        Current unused space.

    AddSpaceDbMB

        Recommended operational free space.

    AddSpaceIndexMB

        Recommended free space required to rebuild the
        largest index associated with the file.

    OptimalSizeMB

        Recommended target file size.

    ShrinkSizeMB

        Potential reclaimable space.

    ReclaimablePct

        Percentage of file space potentially reclaimable.

    Recommendation

        Ignore
            Less than 1 GB reclaimable

        Review
            Between 1 GB and 10 GB reclaimable

        Potential Candidate
            More than 10 GB reclaimable

WARNING

    Shrinking data files should not be part of regular maintenance.

    Always review workload growth trends before shrinking files.

******************************************************************************/

USE [tempdb]
GO

SET QUOTED_IDENTIFIER OFF
GO

--------------------------------------------------------------------------------
-- STEP 1
-- CREATE WORK TABLE
--------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#tFiles', 'U') IS NOT NULL
    DROP TABLE #tFiles;

CREATE TABLE #tFiles
(
      DatabaseName      NVARCHAR(128) NOT NULL
    , Type              VARCHAR(4) NOT NULL
    , data_space_id     INT NOT NULL
    , FileName          NVARCHAR(256) NOT NULL
    , CurrentSizeUpMB   BIGINT NOT NULL
    , UsedSpaceUpMB     BIGINT NOT NULL
    , FreeSpaceMB       BIGINT NOT NULL
    , AddSpaceDbMB      BIGINT NOT NULL
    , AddSpaceIndexMB   BIGINT NULL
);

--------------------------------------------------------------------------------
-- STEP 2
-- COLLECT FILE INFORMATION
--------------------------------------------------------------------------------

EXEC sp_MSforeachdb N'

USE [?];

INSERT INTO #tFiles
SELECT DB_NAME() AS DatabaseName
      ,CASE
          WHEN type = 0 THEN ''data''
          ELSE ''log''
       END AS type
      ,data_space_id
      ,name AS FileName
      ,ISNULL(CAST(CEILING(size / 128.0) AS BIGINT), 0) AS CurrentSizeUpMB
      ,ISNULL(CAST(CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0) AS BIGINT), 0) AS UsedSpaceUpMB
      ,ISNULL
      (CAST(CEILING(size / 128.0) AS BIGINT) - CAST(CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0) AS BIGINT), 0) AS FreeSpaceMB
      ,CASE
          WHEN ISNULL(CAST(CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0) AS BIGINT), 0) <= 32 * 1024
          THEN ISNULL(CAST(CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0 / (1.0 - 0.24)) - CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0) AS BIGINT), 0)
          WHEN ISNULL(CAST(CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0) AS BIGINT), 0) >= 4096 * 1024
          THEN ISNULL(CAST(CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0 / (1.0 - 0.10)) - CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0) AS BIGINT), 0)
          ELSE ISNULL(CAST(CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0 / (1.0 - 0.15 * LOG(256 * 1024)/LOG (ISNULL(CAST(CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0) AS BIGINT), 0)))) - CEILING(CAST(FILEPROPERTY(name,''SpaceUsed'') AS BIGINT) / 128.0)AS BIGINT),0)
      END AS AddSpaceDbMB
     ,NULL
FROM sys.database_files;';

--------------------------------------------------------------------------------
-- STEP 3
-- CALCULATE LOG FILE REBUILD RESERVE
--------------------------------------------------------------------------------

EXEC sp_MSforeachdb N'

USE [?];

;WITH AddIndex AS
(
    SELECT CAST(CEILING(1.2 * MAX(q.SpaceUsedMB)) AS BIGINT) AS AddSpaceIndexMB
    FROM
    (
        SELECT CAST(CEILING(SUM(ISNULL(total_pages,0) / 128.0)) AS BIGINT) AS SpaceUsedMB
              ,p.object_id
              ,p.index_id
              ,au.data_space_id
        FROM sys.partitions p
        INNER JOIN sys.allocation_units au ON p.partition_id = au.container_id
        WHERE p.index_id BETWEEN 1 AND 254
        GROUP BY au.data_space_id, p.object_id, p.index_id
    ) q
),
Fls AS
(
    SELECT COUNT(*) AS cnt
    FROM sys.database_files
    WHERE type <> 0
)
UPDATE #tFiles
SET AddSpaceIndexMB =
(
    SELECT CAST(CEILING(a.AddSpaceIndexMB * 1.0 / f.cnt) AS BIGINT)
    FROM AddIndex a
    CROSS JOIN Fls f
)
WHERE DatabaseName = N''?''
AND type = ''log'';';

--------------------------------------------------------------------------------
-- STEP 4
-- CALCULATE DATA FILE REBUILD RESERVE
--------------------------------------------------------------------------------

EXEC sp_MSforeachdb N'

USE [?];

;WITH AddIndex AS
(
    SELECT q.data_space_id
          ,CAST(CEILING(1.2 * MAX(q.SpaceUsedMB)) AS BIGINT) AS AddSpaceIndexMB
    FROM
    (
        SELECT CAST(CEILING(SUM(ISNULL(total_pages,0) / 128.0)) AS BIGINT) AS SpaceUsedMB
              ,p.object_id
              ,p.index_id
              ,au.data_space_id
        FROM sys.partitions p
        INNER JOIN sys.allocation_units au ON p.partition_id = au.container_id
        WHERE p.index_id BETWEEN 1 AND 254
        GROUP BY au.data_space_id, p.object_id, p.index_id
    ) q
    GROUP BY q.data_space_id
),
Fls AS
(
    SELECT data_space_id
          ,COUNT(*) AS cnt
    FROM sys.database_files
    WHERE type = 0
    GROUP BY data_space_id
)
UPDATE #tFiles
SET AddSpaceIndexMB =
(
    SELECT CAST(CEILING(a.AddSpaceIndexMB * 1.0 / f.cnt) AS BIGINT)
    FROM AddIndex a
    INNER JOIN Fls f ON a.data_space_id = f.data_space_id
    WHERE a.data_space_id = #tFiles.data_space_id
)
WHERE DatabaseName = N''?''
AND type = ''data'';

';

--------------------------------------------------------------------------------
-- STEP 5
-- FINAL REPORT
--------------------------------------------------------------------------------

;WITH Results AS
(
    SELECT DatabaseName
          ,[Type]
          ,data_space_id
          ,[FileName]
          ,CurrentSizeUpMB
          ,UsedSpaceUpMB
          ,FreeSpaceMB
          ,AddSpaceDbMB
          ,AddSpaceIndexMB
          ,UsedSpaceUpMB + IIF(AddSpaceDbMB > AddSpaceIndexMB, AddSpaceDbMB, AddSpaceIndexMB) AS OptimalSizeMB
          ,IIF(CurrentSizeUpMB - (UsedSpaceUpMB + IIF(AddSpaceDbMB > AddSpaceIndexMB, AddSpaceDbMB, AddSpaceIndexMB)) > 0, CurrentSizeUpMB - (UsedSpaceUpMB + IIF(AddSpaceDbMB > AddSpaceIndexMB, AddSpaceDbMB, AddSpaceIndexMB)), 0) AS ShrinkSizeMB
    FROM #tFiles
)
SELECT DatabaseName
      ,[Type]
      --,data_space_id AS [DataSpaceId]
      ,[FileName]
      ,CurrentSizeUpMB
      ,UsedSpaceUpMB
      ,FreeSpaceMB
      ,AddSpaceDbMB
      ,AddSpaceIndexMB
      ,OptimalSizeMB
      ,ShrinkSizeMB
      ,CAST(100.0 * ShrinkSizeMB / NULLIF(CurrentSizeUpMB,0) AS DECIMAL(10,2)) AS ReclaimablePct
      ,CAST(100.0 * FreeSpaceMB / NULLIF(CurrentSizeUpMB,0) AS DECIMAL(10,2)) AS FreeSpacePct
      ,CASE
          WHEN FreeSpaceMB < 10240 THEN 'DO NOT SHRINK - Less than 10 GB free space'
          WHEN (100.0 * FreeSpaceMB / NULLIF(CurrentSizeUpMB,0)) < 30 THEN 'DO NOT SHRINK - Less than 30% free space'
          WHEN ShrinkSizeMB < 10240 THEN 'DO NOT SHRINK - Less than 10 GB reclaimable'
          ELSE 'REVIEW SHRINK OPPORTUNITY'
       END AS ShrinkRecommendation
      ,CASE 
          WHEN FreeSpaceMB < 10240 THEN '-- SHRINK NOT RECOMMENDED: Less than 10 GB free space'
          WHEN (100.0 * FreeSpaceMB / NULLIF(CurrentSizeUpMB,0)) < 30 THEN '-- SHRINK NOT RECOMMENDED: Less than 30% free space'
          WHEN ShrinkSizeMB < 10240 THEN '-- SHRINK NOT RECOMMENDED: Less than 10 GB reclaimable'
          ELSE '
/*
-- DatabaseName      : ' + DatabaseName + '
-- Current Size      : ' + CAST(CurrentSizeUpMB AS varchar(20)) + ' MB
-- Used Space        : ' + CAST(UsedSpaceUpMB AS varchar(20)) + ' MB
-- Free Space        : ' + CAST(FreeSpaceMB AS varchar(20)) + ' MB
-- Optimal Size      : ' + CAST(OptimalSizeMB AS varchar(20)) + ' MB
-- Reclaimable Space : ' + CAST(ShrinkSizeMB AS varchar(20)) + ' MB
*/

USE [' + DatabaseName + '];
GO

DBCC SHRINKFILE (N''' + FileName + ''',' + CAST(OptimalSizeMB AS varchar(20)) + ');
GO'
END AS ProposedShrinkScript
FROM Results
WHERE DatabaseName NOT IN (N'master', N'msdb', N'tempdb', N'model', N'Admin')
ORDER BY type ,ShrinkSizeMB DESC ,FileName;

--------------------------------------------------------------------------------
-- OPTIONAL SUMMARY
--------------------------------------------------------------------------------

/*
;WITH Results AS
(
    SELECT CurrentSizeUpMB
          ,UsedSpaceUpMB
          ,UsedSpaceUpMB + IIF(AddSpaceDbMB > AddSpaceIndexMB,AddSpaceDbMB,AddSpaceIndexMB) AS OptimalSizeMB
          ,IIF(CurrentSizeUpMB - (UsedSpaceUpMB + IIF(AddSpaceDbMB > AddSpaceIndexMB, AddSpaceDbMB, AddSpaceIndexMB)) > 0, CurrentSizeUpMB - (UsedSpaceUpMB + IIF(AddSpaceDbMB > AddSpaceIndexMB, AddSpaceDbMB, AddSpaceIndexMB)), 0) AS ShrinkSizeMB
    FROM #tFiles
)
SELECT SUM(CurrentSizeUpMB) AS TotalCurrentSizeMB
      ,SUM(OptimalSizeMB) AS TotalOptimalSizeMB
      ,SUM(ShrinkSizeMB) AS TotalRecoverableMB
FROM Results;
*/