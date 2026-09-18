DECLARE @who TABLE(
SPID INT,
BLOCKED INT,
BATCH VARCHAR(8000)
)

INSERT INTO @who
SELECT SPID, BLOCKED, CAST(REPLACE (REPLACE (T.TEXT, CHAR(10), ' '), CHAR (13), ' ' ) AS VARCHAR(8000)) AS BATCH
FROM sys.sysprocesses R CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T

;WITH BLOCKERS (SPID, BLOCKED, LEVEL, BATCH)
AS
(
                SELECT SPID
                                 ,BLOCKED
                                 ,CAST (REPLICATE ('0', 4-LEN (CAST (SPID AS VARCHAR))) + CAST (SPID AS VARCHAR) AS VARCHAR (1000)) AS LEVEL
                                 ,BATCH 
                FROM @who R
                WHERE (BLOCKED = 0 OR BLOCKED = SPID)
                AND EXISTS (SELECT * FROM @who R2 
                                                   WHERE R2.BLOCKED = R.SPID 
                                                               AND R2.BLOCKED <> R2.SPID)
                UNION ALL
                SELECT R.SPID
                ,R.BLOCKED
                ,CAST (BLOCKERS.LEVEL + RIGHT (CAST ((1000 + R.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL
                ,R.BATCH 
                FROM @who AS R
                INNER JOIN BLOCKERS ON R.BLOCKED = BLOCKERS.SPID 
                WHERE R.BLOCKED > 0 
                AND R.BLOCKED <> R.SPID
)
SELECT ROW_NUMBER() OVER (ORDER BY @@SERVERNAME) AS RowId, @@SERVERNAME AS InstancesName, '    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) +
                   CASE 
                               WHEN (LEN(LEVEL)/4 - 1) = 0
                                               THEN 'HEAD -  '
                               ELSE '|------  ' END
                   + CAST (SPID AS NVARCHAR (10)) + N' ' + BATCH AS BlockingTree
FROM BLOCKERS ORDER BY LEVEL ASC