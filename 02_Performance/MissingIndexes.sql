SELECT db.name AS DatabaseName
	  --,mid.object_id AS ObjectID
	  --,OBJECT_NAME(mid.object_id, db.database_id) AS 'ObjectName'
	  ,mid.statement AS 'FullyQualifiedObjectName'
	  ,mid.equality_columns AS 'EqualityColumns'
	  ,mid.inequality_columns AS 'InEqualityColumns'
	  ,mid.included_columns AS 'IncludedColumns'
	  ,migs.unique_compiles AS 'UniqueCompiles'
	  ,migs.user_seeks AS 'UserSeeks'
	  --,migs.user_scans AS 'UserScans'
	  ,migs.last_user_seek AS 'LastUserSeekTime'
	  --,migs.last_user_scan AS 'LastUserScanTime'
	  ,migs.avg_total_user_cost AS 'AvgTotalUserCost'
	  ,migs.avg_user_impact AS 'AvgUserImpact'
	  ,migs.user_seeks * migs.avg_total_user_cost * (migs.avg_user_impact * 0.01) AS 'IndexAdvantage'
	  ,'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id, db.database_id) + '_' + REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns, ''), ', ', '_'), '', ''), '', '') + 
		CASE
	      WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN '_'
	      ELSE ''
	    END + REPLACE(REPLACE(REPLACE(ISNULL(mid.inequality_columns, ''), ', ', '_'), '', ''), '', '') + '_' + LEFT(CAST(NEWID() AS NVARCHAR(64)), 5) + '' + ' ON ' + mid.statement + ' (' + ISNULL(mid.equality_columns, '') + 
		CASE
	      WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ','
	      ELSE ''
	    END + ISNULL(mid.inequality_columns, '') + ')' + ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS 'ProposedIndex'
	  ,CAST(CURRENT_TIMESTAMP AS smalldatetime) AS 'CollectionDate'
FROM sys.dm_db_missing_index_group_stats migs WITH (NOLOCK)
INNER JOIN sys.dm_db_missing_index_groups mig WITH (NOLOCK) ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid WITH (NOLOCK) ON mig.index_handle = mid.index_handle
INNER JOIN sys.databases db WITH (NOLOCK) ON db.database_id = mid.database_id
WHERE  db.database_id = DB_ID()
ORDER BY IndexAdvantage DESC