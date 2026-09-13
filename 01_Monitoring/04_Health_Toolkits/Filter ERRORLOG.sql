/******************************************************************************
SQL SERVER ERROR LOG DIAGNOSTIC & SECURITY FILTER
-------------------------------------------------------------------------------
PURPOSE

This diagnostic script provides safe, fast, parameterized searching of the
SQL Server Error Log for authentication failures, account lockouts, high-severity
errors, and I/O corruption warnings without loading entire multi-gigabyte logs into memory.

TARGET COMPATIBILITY
    SQL Server 2019 and later (Enterprise, Standard, Developer)

SAFETY & PERMISSIONS
    Read-Only diagnostic script.
    Requires: VIEW SERVER STATE (SQL 2019) / VIEW SERVER PERFORMANCE STATE (SQL 2022)

AREAS COVERED

1. Recent Authentication Failures & Failed Logons (Last 24 Hours)
2. Aggregated Failed Logins by Account & Client Source
3. Critical Database Engine Errors (Severity 17-25, Corruption, I/O)
4. Account Lockouts & Security Alerts
5. Custom Keyword Search Parameter Template

******************************************************************************/

/*-----------------------------------------------------------------------------
    SECTION 1
    RECENT AUTHENTICATION FAILURES (LAST 24 HOURS)
-------------------------------------------------------------------------------
.PURPOSE
    Search the active SQL Server Error Log specifically for failed logins.

.NOTE
    Using parameterized sp_readerrorlog filters at the engine level before returning.
-----------------------------------------------------------------------------*/

IF OBJECT_ID('tempdb..#FailedLogins') IS NOT NULL
    DROP TABLE #FailedLogins;

CREATE TABLE #FailedLogins
(
    LogDate DATETIME,
    ProcessInfo NVARCHAR(32),
    LogText NVARCHAR(4000)
);

-- Search active error log (0) for 'Login failed'
INSERT INTO #FailedLogins (LogDate, ProcessInfo, LogText)
EXEC sys.sp_readerrorlog 0, 1, N'Login failed', NULL;

SELECT
    LogDate,
    ProcessInfo,
    LogText
FROM #FailedLogins
WHERE LogDate >= DATEADD(HOUR, -24, GETDATE())
ORDER BY LogDate DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 2
    AGGREGATED FAILED LOGINS BY ACCOUNT & CLIENT SOURCE
-------------------------------------------------------------------------------
.PURPOSE
    Group recent failed login attempts to identify brute force attacks or misconfigured apps.
-----------------------------------------------------------------------------*/

SELECT
    COUNT(*) AS FailedAttemptCount,
    MIN(LogDate) AS FirstAttemptTime,
    MAX(LogDate) AS LastAttemptTime,
    SUBSTRING(
        LogText,
        CHARINDEX('''', LogText) + 1,
        CHARINDEX('''', LogText, CHARINDEX('''', LogText) + 1) - CHARINDEX('''', LogText) - 1
    ) AS TargetLoginName,
    CASE
        WHEN CHARINDEX('[CLIENT:', LogText) > 0
        THEN SUBSTRING(
            LogText,
            CHARINDEX('[CLIENT:', LogText) + 9,
            CHARINDEX(']', LogText, CHARINDEX('[CLIENT:', LogText)) - CHARINDEX('[CLIENT:', LogText) - 9
        )
        ELSE 'Local / Shared Memory'
    END AS ClientIPAddress
FROM #FailedLogins
WHERE LogDate >= DATEADD(DAY, -7, GETDATE())
  AND CHARINDEX('''', LogText) > 0
GROUP BY
    SUBSTRING(
        LogText,
        CHARINDEX('''', LogText) + 1,
        CHARINDEX('''', LogText, CHARINDEX('''', LogText) + 1) - CHARINDEX('''', LogText) - 1
    ),
    CASE
        WHEN CHARINDEX('[CLIENT:', LogText) > 0
        THEN SUBSTRING(
            LogText,
            CHARINDEX('[CLIENT:', LogText) + 9,
            CHARINDEX(']', LogText, CHARINDEX('[CLIENT:', LogText)) - CHARINDEX('[CLIENT:', LogText) - 9
        )
        ELSE 'Local / Shared Memory'
    END
ORDER BY FailedAttemptCount DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 3
    CRITICAL DATABASE ENGINE ERRORS & CORRUPTION
-------------------------------------------------------------------------------
.PURPOSE
    Scan active error log for fatal errors, 823/824/825 I/O errors, or corruptions.
-----------------------------------------------------------------------------*/

IF OBJECT_ID('tempdb..#CriticalErrors') IS NOT NULL
    DROP TABLE #CriticalErrors;

CREATE TABLE #CriticalErrors
(
    LogDate DATETIME,
    ProcessInfo NVARCHAR(32),
    LogText NVARCHAR(4000)
);

INSERT INTO #CriticalErrors (LogDate, ProcessInfo, LogText)
EXEC sys.sp_readerrorlog 0, 1, N'Error:', NULL;

SELECT
    LogDate,
    ProcessInfo,
    LogText
FROM #CriticalErrors
WHERE LogText LIKE '%Severity: 1[7-9]%'
   OR LogText LIKE '%Severity: 2[0-5]%'
   OR LogText LIKE '%823%'
   OR LogText LIKE '%824%'
   OR LogText LIKE '%825%'
   OR LogText LIKE '%corrupt%'
ORDER BY LogDate DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 4
    ACCOUNT LOCKOUTS & SECURITY ALERTS
-------------------------------------------------------------------------------
.PURPOSE
    Identify accounts locked out by Windows or SQL Server password policy.
-----------------------------------------------------------------------------*/

IF OBJECT_ID('tempdb..#LockoutLog') IS NOT NULL
    DROP TABLE #LockoutLog;

CREATE TABLE #LockoutLog
(
    LogDate DATETIME,
    ProcessInfo NVARCHAR(32),
    LogText NVARCHAR(4000)
);

INSERT INTO #LockoutLog (LogDate, ProcessInfo, LogText)
EXEC sys.sp_readerrorlog 0, 1, N'locked out', NULL;

SELECT
    LogDate,
    ProcessInfo,
    LogText
FROM #LockoutLog
ORDER BY LogDate DESC;
GO

/*-----------------------------------------------------------------------------
    SECTION 5
    CUSTOM KEYWORD SEARCH PARAMETER TEMPLATE
-------------------------------------------------------------------------------
.PURPOSE
    Template for DBAs to perform arbitrary dual-keyword searches across any log archive.
-----------------------------------------------------------------------------*/

-- Parameters: LogArchiveNumber (0=Active, 1=Archive #1), LogType (1=SQL, 2=Agent), SearchString1, SearchString2
DECLARE @ArchiveNumber INT = 0;
DECLARE @LogType INT = 1;
DECLARE @SearchString1 NVARCHAR(100) = N'deadlock';
DECLARE @SearchString2 NVARCHAR(100) = NULL;

EXEC sys.sp_readerrorlog @ArchiveNumber, @LogType, @SearchString1, @SearchString2;
GO
