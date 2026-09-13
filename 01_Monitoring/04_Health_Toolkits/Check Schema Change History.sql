/******************************************************************************
SQL SERVER SCHEMA CHANGE & DDL AUDIT HISTORY
-------------------------------------------------------------------------------
PURPOSE

This diagnostic script identifies recent database schema changes (CREATE, ALTER,
DROP operations) captured by the SQL Server Default Trace and system events,
showing who made the change, from which application, and at what time.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Recent DDL Operations from Default Trace (CREATE, ALTER, DROP)
2. Schema Changes Grouped by Database, Object & Login
3. Schema Change Summary Statistics

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    RECENT DDL OPERATIONS FROM DEFAULT TRACE
-------------------------------------------------------------------------------
.PURPOSE
    Extract DDL events (EventClass 46=CREATE, 47=DROP, 164=ALTER) from default trace.
-----------------------------------------------------------------------------*/

DECLARE @curr_tracefilename NVARCHAR(500);
DECLARE @base_tracefilename NVARCHAR(500);
DECLARE @indx INT;

SELECT @curr_tracefilename = [path]
FROM sys.traces
WHERE is_default = 1;

IF @curr_tracefilename IS NULL
BEGIN
    PRINT 'Default Trace is not enabled on this instance.';
END
ELSE
BEGIN
    SET @curr_tracefilename = REVERSE(@curr_tracefilename);
    SELECT @indx = PATINDEX('%\%', @curr_tracefilename);
    SET @curr_tracefilename = REVERSE(@curr_tracefilename);
    SET @base_tracefilename = LEFT(@curr_tracefilename, LEN(@curr_tracefilename) - @indx) + '\log.trc';

    SELECT
        StartTime AS EventTime,
        DatabaseName,
        ObjectName,
        CASE EventClass
            WHEN 46 THEN 'CREATE'
            WHEN 47 THEN 'DROP'
            WHEN 164 THEN 'ALTER'
            ELSE 'OTHER'
        END AS DDLOperation,
        CASE ObjectType
            WHEN 8259 THEN 'Check Constraint'
            WHEN 8260 THEN 'Default Constraint'
            WHEN 8262 THEN 'Foreign Key'
            WHEN 8272 THEN 'Stored Procedure'
            WHEN 8274 THEN 'Rule'
            WHEN 8275 THEN 'System Table'
            WHEN 8276 THEN 'Trigger'
            WHEN 8277 THEN 'User Table'
            WHEN 8278 THEN 'View'
            WHEN 8280 THEN 'Extended Stored Procedure'
            WHEN 16964 THEN 'Database'
            WHEN 16975 THEN 'Object'
            WHEN 16996 THEN 'User'
            WHEN 16997 THEN 'Schema'
            WHEN 17222 THEN 'FullText Catalog'
            WHEN 17232 THEN 'CLR Stored Procedure'
            WHEN 17235 THEN 'CLR Trigger'
            WHEN 17475 THEN 'Credential'
            WHEN 17491 THEN 'DDL Event'
            WHEN 17746 THEN 'Security Policy'
            WHEN 17750 THEN 'Sequence'
            WHEN 17985 THEN 'CLR Aggregate'
            WHEN 17993 THEN 'Inline TVF'
            WHEN 18002 THEN 'Scalar Function'
            WHEN 18004 THEN 'Multi-Statement TVF'
            WHEN 19277 THEN 'Event Session'
            WHEN 19754 THEN 'Search Property List'
            WHEN 20038 THEN 'Scalar UDF'
            WHEN 20051 THEN 'Synonym'
            WHEN 20549 THEN 'Security Key'
            WHEN 21587 THEN 'Statistics'
            ELSE 'Type ID ' + CAST(ObjectType AS VARCHAR(10))
        END AS ObjectTypeDescription,
        LoginName,
        ApplicationName,
        HostName,
        ServerName,
        SPID
    FROM sys.fn_trace_gettable(@base_tracefilename, DEFAULT)
    WHERE EventClass IN (46, 47, 164)
      AND EventSubclass = 0
      AND DatabaseID <> 2 -- Exclude tempdb
      AND ObjectType <> 21587 -- Exclude auto-created statistics
    ORDER BY StartTime DESC;
END;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    SCHEMA CHANGES GROUPED BY DATABASE & LOGIN (LAST 7 DAYS)
-------------------------------------------------------------------------------
.PURPOSE
    Aggregate recent DDL activity to detect deployments or unauthorized changes.
-----------------------------------------------------------------------------*/

DECLARE @curr_tracefilename NVARCHAR(500);
DECLARE @base_tracefilename NVARCHAR(500);
DECLARE @indx INT;

SELECT @curr_tracefilename = [path]
FROM sys.traces
WHERE is_default = 1;

IF @curr_tracefilename IS NOT NULL
BEGIN
    SET @curr_tracefilename = REVERSE(@curr_tracefilename);
    SELECT @indx = PATINDEX('%\%', @curr_tracefilename);
    SET @curr_tracefilename = REVERSE(@curr_tracefilename);
    SET @base_tracefilename = LEFT(@curr_tracefilename, LEN(@curr_tracefilename) - @indx) + '\log.trc';

    SELECT
        DatabaseName,
        LoginName,
        ApplicationName,
        CASE EventClass
            WHEN 46 THEN 'CREATE'
            WHEN 47 THEN 'DROP'
            WHEN 164 THEN 'ALTER'
        END AS DDLOperation,
        COUNT(*) AS EventCount,
        MIN(StartTime) AS FirstEventTime,
        MAX(StartTime) AS LastEventTime
    FROM sys.fn_trace_gettable(@base_tracefilename, DEFAULT)
    WHERE EventClass IN (46, 47, 164)
      AND EventSubclass = 0
      AND DatabaseID <> 2
      AND ObjectType <> 21587
    GROUP BY
        DatabaseName,
        LoginName,
        ApplicationName,
        CASE EventClass
            WHEN 46 THEN 'CREATE'
            WHEN 47 THEN 'DROP'
            WHEN 164 THEN 'ALTER'
        END
    ORDER BY LastEventTime DESC;
END;
GO
