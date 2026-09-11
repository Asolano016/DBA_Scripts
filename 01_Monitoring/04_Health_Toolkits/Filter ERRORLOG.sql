SET QUOTED_IDENTIFIER OFF;

IF OBJECT_ID('tempdb..#tSQLErrorLog') IS NOT NULL
DROP TABLE #tSQLErrorLog

IF OBJECT_ID('tempdb..#tLogonLog') IS NOT NULL
DROP TABLE #tLogonLog

CREATE TABLE #tSQLErrorLog
(
	LogDate DATETIME,
	ProcessInfo NVARCHAR(12),
	LogText NVARCHAR(3999)
)

INSERT INTO #tSQLErrorLog (LogDate, ProcessInfo, LogText)
EXEC sp_readerrorlog;

SELECT *
FROM #tSQLErrorLog
ORDER BY logdate DESC


SELECT LogDate
	  ,ProcessInfo
	  ,LogText
	  ,CASE 
		WHEN LogText LIKE '%Password did not match that for the login provided.%'
		THEN LEFT(REVERSE(SUBSTRING(REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), CHARINDEX('''', REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), 0), LEN(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText)))) ), LEN(SUBSTRING(REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), CHARINDEX('''', REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), 0), LEN(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText)))))-1)
		WHEN LogText LIKE '%The account is currently locked out. The system administrator can unlock it.%'
		THEN LEFT(REVERSE(SUBSTRING(REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), CHARINDEX('''', REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), 0), LEN(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText)))) ), LEN(SUBSTRING(REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), CHARINDEX('''', REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), 0), LEN(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText)))))-1)
		WHEN LogText LIKE '%Login succeeded for user%'
		THEN LEFT(REVERSE(SUBSTRING(REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), CHARINDEX('''', REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), 0), LEN(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText)))) ), LEN(SUBSTRING(REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), CHARINDEX('''', REVERSE(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText))), 0), LEN(SUBSTRING(LogText, CHARINDEX('''', LogText, 0) + 1, LEN(LogText)))))-1)
		ELSE NULL
	 END LoginName
	,CASE
		WHEN LogText LIKE '%Password did not match that for the login provided.%'
		THEN LEFT(SUBSTRING(LogText, CHARINDEX('T: ', LogText, 0) + 3, LEN(LogText)), LEN(SUBSTRING(LogText, CHARINDEX('T: ', LogText, 0) + 3, LEN(LogText))) - 1)
		WHEN LogText LIKE '%The account is currently locked out. The system administrator can unlock it.%'
		THEN LEFT(SUBSTRING(LogText, CHARINDEX('T: ', LogText, 0) + 3, LEN(LogText)), LEN(SUBSTRING(LogText, CHARINDEX('T: ', LogText, 0) + 3, LEN(LogText))) - 1)
		WHEN LogText LIKE '%Login succeeded for user%'
		THEN LEFT(SUBSTRING(LogText, CHARINDEX('T: ', LogText, 0) + 3, LEN(LogText)), LEN(SUBSTRING(LogText, CHARINDEX('T: ', LogText, 0) + 3, LEN(LogText))) - 1)
		ELSE NULL
	 END Client
--INTO #tLogonLog
FROM #tSQLErrorLog
--WHERE LogDate <= '2022-03-09 20:33:08' AND LogDate >= '2022-03-05 16:10:35' 
--AND ProcessInfo = 'Logon'
ORDER BY LogDate DESC

--SELECT LoginName
--	    ,Client
--	    ,LogText
--	    ,COUNT(LoginName) AS LoginNameCount 
--FROM #tLogonLog
--WHERE LogText LIKE '%Password did not match that for the login provided.%'
--OR LogText LIKE '%The account is currently locked out. The system administrator can unlock it.%'
--GROUP BY LoginName, Client, LogText
--ORDER BY LoginName, LogText