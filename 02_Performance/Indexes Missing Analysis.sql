/*-------------------------------------------------------------------------------
    MISSING INDEX OPPORTUNITY ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Identify potentially beneficial indexes based on workload activity
    observed by the SQL Server Query Optimizer.

.WHY THIS MATTERS

    SQL Server records instances where it believes an index could have
    improved query performance.

    These recommendations can help reduce:

        • Logical Reads
        • Physical Reads
        • CPU Consumption
        • Query Duration
        • Execution Plan Cost

    However, recommendations should always be reviewed before
    implementation.

.IMPORTANT LIMITATIONS

    SQL Server Missing Index DMVs DO NOT evaluate:

        Existing similar indexes
        Duplicate indexes
        Storage requirements
        Index maintenance overhead
        INSERT/UPDATE/DELETE impact
        Workload-wide index strategy

    Do NOT automatically create every recommended index.

.KEY COLUMNS

    DatabaseName

        Database where SQL Server identified the missing index.

    FullyQualifiedObjectName

        Target table requiring additional indexing.

    EqualityColumns

        Columns frequently used in equality predicates.

        Example:

            WHERE CustomerID = 100

        These columns typically belong first in the index key.

    InEqualityColumns

        Columns used in range predicates.

        Examples:

            >
            <
            >=
            <=
            BETWEEN

        These typically follow EqualityColumns in the index key.

    IncludedColumns

        Additional columns recommended as INCLUDE columns.

        These are typically suggested to eliminate
        Key Lookups and create covering indexes.

    UserSeeks

        Number of times SQL Server wanted to use
        the recommended index through seeks.

        Higher values indicate greater demand.

    UserScans

        Number of scans potentially improved by the recommended index.

        Higher values may indicate table scanning workloads.

    LastUserSeekTime

        Last time SQL Server observed a query
        that would benefit from this index.

    DaysSinceLastSeek

        Helps determine whether the recommendation
        is still relevant.

    AvgTotalUserCost

        Average estimated cost of affected queries.

        Higher values generally indicate more expensive queries.

    AvgUserImpact

        Estimated percentage improvement.

        Example:

            80 = SQL Server estimates ~80% improvement.

        This value is only an estimate.

    IndexAdvantage

        Composite score used to prioritize recommendations.

        Formula:

            (UserSeeks + UserScans)
            × AvgTotalUserCost
            × AvgUserImpact

        Higher values indicate higher potential benefit.

    ProposedIndex

        Auto-generated CREATE INDEX statement.

        Review manually before implementation.

.INTERPRETING RESULTS

    HIGH PRIORITY CANDIDATE

        UserSeeks > 1000

        AvgUserImpact > 75

        DaysSinceLastSeek < 30

        Large IndexAdvantage score

    Example:

        UserSeeks           = 25,000
        AvgUserImpact       = 92
        AvgTotalUserCost    = 40

        Interpretation:

            Strong candidate for evaluation.

------------------------------------------------------------------------------
    MEDIUM PRIORITY CANDIDATE

        UserSeeks between 100 and 1000

        AvgUserImpact between 50 and 75

        Recent LastUserSeekTime

        Moderate IndexAdvantage

    Interpretation:

        Worth evaluating during normal tuning activities.

------------------------------------------------------------------------------
    LOW PRIORITY CANDIDATE

        UserSeeks < 100

        DaysSinceLastSeek > 90

        Low IndexAdvantage

    Interpretation:

        Lower business value.
        Usually not urgent.

.POSSIBLE FALSE POSITIVES

    BEFORE creating an index, always verify:

        Existing indexes on the table.
        Duplicate indexes.
        Similar composite indexes.
        Covering indexes already available.
        Current storage footprint.
        Write-heavy workload impact.

.EXAMPLE REVIEW PROCESS

    Step 1

        Sort by IndexAdvantage DESC.

------------------------------------------------------------------------------
    Step 2

        Focus on top recommendations first.

------------------------------------------------------------------------------
    Step 3

        Validate existing indexes.

        Review:

            Health Index Toolkit

------------------------------------------------------------------------------
    Step 4

        Identify affected queries.

        Review:

            Health Query Performance Toolkit

------------------------------------------------------------------------------
    Step 5

        Review execution plans.

        Look for:

            Table Scans
            Index Scans
            Key Lookups

------------------------------------------------------------------------------
    Step 6

        Implement carefully and validate benefit.

.COMMON DECISION FRAMEWORK

    Create Immediately

        High IndexAdvantage
        High UserSeeks
        Recent activity
        No similar index exists

------------------------------------------------------------------------------
    Review Further

        Moderate IndexAdvantage
        Existing similar indexes

------------------------------------------------------------------------------
    Usually Ignore

        Old recommendations
        Very low UserSeeks
        Minimal business impact

.RELATED TOOLKITS

    Health Query Performance
    Health CPU
    Health IO
    Health Indexes

------------------------------------------------------------------------------*/

SELECT db.name AS DatabaseName
	  --,mid.object_id AS ObjectID
	  --,OBJECT_NAME(mid.object_id, db.database_id) AS 'ObjectName'
	  ,mid.statement AS 'FullyQualifiedObjectName'
	  ,mid.equality_columns AS 'EqualityColumns'
	  ,mid.inequality_columns AS 'InEqualityColumns'
	  ,mid.included_columns AS 'IncludedColumns'
	  ,migs.unique_compiles AS 'UniqueCompiles'
	  ,migs.user_seeks AS 'UserSeeks'
	  ,migs.user_scans AS 'UserScans'
	  ,migs.last_user_seek AS 'LastUserSeekTime'
	  --,migs.last_user_scan AS 'LastUserScanTime'
	  ,CASE
			WHEN migs.last_user_seek IS NULL THEN NULL
			ELSE DATEDIFF(DAY, migs.last_user_seek, GETDATE())
	   END AS DaysSinceLastSeek
	  ,CASE
			WHEN migs.last_user_seek IS NULL THEN 'Never Used'
			WHEN DATEDIFF(DAY,migs.last_user_seek,GETDATE()) <= 7 THEN 'Recent'
			WHEN DATEDIFF(DAY,migs.last_user_seek,GETDATE()) <= 30 THEN 'Moderate'
			ELSE 'Old'
	   END AS RecommendationAge
	  ,migs.avg_total_user_cost AS 'AvgTotalUserCost'
	  ,migs.avg_user_impact AS 'AvgUserImpact'
	  ,(migs.user_seeks + migs.user_scans) * migs.avg_total_user_cost * (migs.avg_user_impact * 0.01) AS ImpactScore
	  --,migs.user_seeks * migs.avg_total_user_cost * (migs.avg_user_impact * 0.01) AS 'IndexAdvantageOld'
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
FROM sys.dm_db_missing_index_group_stats migs
INNER JOIN sys.dm_db_missing_index_groups mig ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
INNER JOIN sys.databases db ON db.database_id = mid.database_id
WHERE  db.database_id = DB_ID()
ORDER BY ImpactScore DESC, UserSeeks DESC




