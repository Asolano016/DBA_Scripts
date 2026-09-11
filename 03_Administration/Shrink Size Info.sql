/*====================================================================
  Estimate potential reclaimable space for DATA and LOG files
  - Per-file and total estimates
  - Recommends a target size = Used + Buffer%

  Parameters:
    @DatabaseName  : sysname   -- database to assess
    @BufferPct     : decimal   -- % of used space to keep as safety (default 10%)

  Safe: READ-ONLY (no shrink is executed)
====================================================================*/
DECLARE @DatabaseName sysname = N'dwdata';
DECLARE @BufferPct    decimal(5,2) = 10.00; -- percent of USED to keep as buffer

/*------------------------------------------------------------
  Validate DB exists
------------------------------------------------------------*/
IF DB_ID(@DatabaseName) IS NULL
BEGIN
    RAISERROR('Database %s not found.', 16, 1, @DatabaseName);
    RETURN;
END

/*------------------------------------------------------------
  Collect per-file sizes
  - For DATA files: FILEPROPERTY([logical_name],'SpaceUsed') returns pages used
  - For LOG: use sys.dm_db_log_space_usage for the whole log (then apportion
    to each log file by size share; also show global log numbers).
------------------------------------------------------------*/
SET NOCOUNT ON;

DECLARE @sql nvarchar(max);

-- Temp tables
IF OBJECT_ID('tempdb..#files') IS NOT NULL DROP TABLE #files;
IF OBJECT_ID('tempdb..#log_usage') IS NOT NULL DROP TABLE #log_usage;
IF OBJECT_ID('tempdb..#report') IS NOT NULL DROP TABLE #report;

CREATE TABLE #files
(
    file_id            int,
    type_desc          nvarchar(60),
    logical_name       sysname,
    physical_name      nvarchar(260),
    size_mb            decimal(19,2),
    used_mb            decimal(19,2) NULL,  -- for data files
    is_log             bit
);

CREATE TABLE #log_usage
(
    total_log_size_mb      decimal(19,2),
    log_space_used_mb      decimal(19,2),
    log_space_used_pct     decimal(9,4)
);

-- Build dynamic SQL to read FILEPROPERTY inside the target DB context
SET @sql = N'
USE ' + QUOTENAME(@DatabaseName) + N';
SELECT
      df.file_id
    , df.type_desc
    , df.name            AS logical_name
    , df.physical_name
    , CONVERT(decimal(19,2), df.size * 8.0 / 1024.0) AS size_mb
    , CASE WHEN df.type = 0  -- DATA
           THEN CONVERT(decimal(19,2), FILEPROPERTY(df.name, ''SpaceUsed'') * 8.0 / 1024.0)
           ELSE NULL
      END AS used_mb
    , CASE WHEN df.type = 1 THEN 1 ELSE 0 END AS is_log
FROM sys.database_files AS df
';

INSERT INTO #files (file_id, type_desc, logical_name, physical_name, size_mb, used_mb, is_log)
EXEC (@sql);

-- Get log usage for the whole DB
SET @sql = N'
USE ' + QUOTENAME(@DatabaseName) + N';
SELECT
    CONVERT(decimal(19,2), total_log_size_in_bytes / 1024.0 / 1024.0) AS total_log_size_mb,
    CONVERT(decimal(19,2), used_log_space_in_bytes  / 1024.0 / 1024.0) AS log_space_used_mb,
    used_log_space_in_percent                                         AS log_space_used_pct
FROM sys.dm_db_log_space_usage;
';
INSERT INTO #log_usage
EXEC (@sql);

-- Prepare a report table
CREATE TABLE #report
(
    file_id                 int,
    type_desc               nvarchar(60),
    logical_name            sysname,
    physical_name           nvarchar(260),
    size_mb                 decimal(19,2),
    used_mb                 decimal(19,2),
    free_mb                 decimal(19,2),
    buffer_mb               decimal(19,2),
    potential_reclaim_mb    decimal(19,2),
    recommended_target_mb   decimal(19,2)
);

DECLARE @log_total_size_mb  decimal(19,2) = (SELECT total_log_size_mb FROM #log_usage);
DECLARE @log_used_mb        decimal(19,2) = (SELECT log_space_used_mb FROM #log_usage);

-- Avoid divide-by-zero
IF @log_total_size_mb IS NULL SET @log_total_size_mb = 0;
IF @log_used_mb IS NULL SET @log_used_mb = 0;

-- For log files: we only know total used across the log.
-- We’ll apportion "used" to each log file by its size share (approximation).
WITH log_files AS
(
    SELECT *,
           SUM(size_mb) OVER() AS total_log_mb
    FROM #files
    WHERE is_log = 1
)
INSERT INTO #report
SELECT
    f.file_id,
    f.type_desc,
    f.logical_name,
    f.physical_name,
    f.size_mb,
    -- used_mb calculation:
    CASE WHEN f.is_log = 0 THEN
         ISNULL(f.used_mb, 0)  -- data files: real used from FILEPROPERTY
         ELSE
         CASE WHEN lf.total_log_mb > 0
              THEN CONVERT(decimal(19,2), @log_used_mb * (f.size_mb / lf.total_log_mb))
              ELSE 0
         END
    END AS used_mb,
    -- free_mb:
    CASE WHEN f.is_log = 0 THEN
         CONVERT(decimal(19,2), f.size_mb - ISNULL(f.used_mb,0))
         ELSE
         CONVERT(decimal(19,2), f.size_mb - 
           CASE WHEN lf.total_log_mb > 0 
                THEN @log_used_mb * (f.size_mb / lf.total_log_mb) 
                ELSE 0 END)
    END AS free_mb,
    -- buffer_mb: BufferPct * used
    CONVERT(decimal(19,2),
        (CASE WHEN f.is_log = 0 
              THEN ISNULL(f.used_mb,0) 
              ELSE CASE WHEN lf.total_log_mb > 0 
                        THEN @log_used_mb * (f.size_mb / lf.total_log_mb) 
                        ELSE 0 END
         END) * (@BufferPct / 100.0)
    ) AS buffer_mb,
    -- potential_reclaim_mb: max(free - buffer, 0)
    CONVERT(decimal(19,2),
        CASE 
            WHEN (CASE WHEN f.is_log = 0 
                       THEN f.size_mb - ISNULL(f.used_mb,0)
                       ELSE f.size_mb - 
                            CASE WHEN lf.total_log_mb > 0 
                                 THEN @log_used_mb * (f.size_mb / lf.total_log_mb) 
                                 ELSE 0 END
                  END)
                 - 
                 ( (CASE WHEN f.is_log = 0 
                         THEN ISNULL(f.used_mb,0) 
                         ELSE CASE WHEN lf.total_log_mb > 0 
                                   THEN @log_used_mb * (f.size_mb / lf.total_log_mb) 
                                   ELSE 0 END
                    END) * (@BufferPct / 100.0)
                 ) > 0
            THEN (CASE WHEN f.is_log = 0 
                       THEN f.size_mb - ISNULL(f.used_mb,0)
                       ELSE f.size_mb - 
                            CASE WHEN lf.total_log_mb > 0 
                                 THEN @log_used_mb * (f.size_mb / lf.total_log_mb) 
                                 ELSE 0 END
                 END)
                 - 
                 ( (CASE WHEN f.is_log = 0 
                         THEN ISNULL(f.used_mb,0) 
                         ELSE CASE WHEN lf.total_log_mb > 0 
                                   THEN @log_used_mb * (f.size_mb / lf.total_log_mb) 
                                   ELSE 0 END
                    END) * (@BufferPct / 100.0)
                 )
            ELSE 0
        END
    ) AS potential_reclaim_mb,
    -- recommended_target_mb = used + buffer
    CONVERT(decimal(19,2),
        (CASE WHEN f.is_log = 0 
              THEN ISNULL(f.used_mb,0) 
              ELSE CASE WHEN lf.total_log_mb > 0 
                        THEN @log_used_mb * (f.size_mb / lf.total_log_mb) 
                        ELSE 0 END
         END) 
         + 
        (CASE WHEN f.is_log = 0 
              THEN ISNULL(f.used_mb,0) 
              ELSE CASE WHEN lf.total_log_mb > 0 
                        THEN @log_used_mb * (f.size_mb / lf.total_log_mb) 
                        ELSE 0 END
         END) * (@BufferPct / 100.0)
    ) AS recommended_target_mb
FROM #files AS f
LEFT JOIN log_files AS lf
  ON lf.file_id = f.file_id;

-- Output
PRINT 'Per-file reclaim estimate (Buffer ' + CONVERT(varchar(20), @BufferPct) + '% of used):';
SELECT
    file_id,
    type_desc,
    logical_name,
    physical_name,
    size_mb,
    used_mb,
    free_mb,
    buffer_mb,
    potential_reclaim_mb,
    recommended_target_mb
FROM #report
ORDER BY CASE WHEN type_desc = 'LOG' THEN 1 ELSE 0 END, file_id;

PRINT 'Totals (data vs log):';
SELECT
    CASE WHEN type_desc = 'LOG' THEN 'LOG' ELSE 'DATA' END AS file_category,
    SUM(size_mb)               AS total_size_mb,
    SUM(used_mb)               AS total_used_mb,
    SUM(free_mb)               AS total_free_mb,
    SUM(potential_reclaim_mb)  AS total_potential_reclaim_mb,
    SUM(recommended_target_mb) AS recommended_target_mb
FROM #report
GROUP BY CASE WHEN type_desc = 'LOG' THEN 'LOG' ELSE 'DATA' END;

PRINT 'Grand totals:';
SELECT
    SUM(size_mb)               AS total_size_mb,
    SUM(used_mb)               AS total_used_mb,
    SUM(free_mb)               AS total_free_mb,
    SUM(potential_reclaim_mb)  AS total_potential_reclaim_mb,
    SUM(recommended_target_mb) AS recommended_target_mb
FROM #report;