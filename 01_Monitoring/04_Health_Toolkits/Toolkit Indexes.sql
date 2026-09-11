/******************************************************************************
SQL SERVER INDEX HEALTH CHECK & TROUBLESHOOTING GUIDE
-------------------------------------------------------------------------------

PURPOSE

This toolkit provides a structured approach for evaluating
index health, identifying tuning opportunities and reducing
unnecessary maintenance overhead.

The goal is to answer:

    • Are indexes missing?
    • Are indexes unused?
    • Do duplicate indexes exist?
    • Are indexes excessively fragmented?
    • Are key lookups hurting performance?
    • Are indexes larger than necessary?
    • Are index updates outweighing index usage?
    • Is index maintenance required?

AREAS COVERED

1. Missing Index Analysis
2. Unused Indexes
3. Low Value Indexes
4. Duplicate Index Detection
5. Fragmentation Analysis
6. Largest Indexes
7. Key Lookup Indicators
8. Index Usage Analysis
9. Index Operational Statistics
10. Executive Summary

WHEN TO USE THIS TOOLKIT

Use this toolkit when:

    • Queries perform poorly
    • Excessive logical reads are observed
    • CPU consumption is elevated
    • Index maintenance is being reviewed
    • Storage growth is increasing
    • Query tuning efforts are underway

RECOMMENDED TROUBLESHOOTING FLOW

Step 1
-------
Review Executive Summary

Step 2
-------
Review Missing Indexes

Step 3
-------
Review Unused Indexes

Step 4
-------
Review Fragmentation

Step 5
-------
Review Key Lookup Indicators

Step 6
-------
Review Operational Statistics

******************************************************************************/




/*-------------------------------------------------------------------------------
    SECTION 1
    MISSING INDEX ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Identify potentially beneficial indexes.

.WHY THIS MATTERS

    Missing indexes often generate excessive reads,
    CPU consumption and poor query performance.

.KEY METRICS

    avg_user_impact

    user_seeks

    equality_columns

    included_columns

.HEALTHY

    Few high-impact recommendations.

.WARNING

    High avg_user_impact values combined with
    large user_seeks counts.

.POSSIBLE CAUSES

    Untuned workload.
    New application functionality.
    Data growth.

.NEXT ACTIONS

    Validate recommendations manually before implementation.

-------------------------------------------------------------------------------*/

SELECT
    migs.avg_user_impact,
    migs.user_seeks,
    mid.statement,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig
    ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs
    ON mig.index_group_handle = migs.group_handle
ORDER BY migs.avg_user_impact DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 2
    UNUSED INDEXES
-------------------------------------------------------------------------------

.PURPOSE

    Identify indexes that are rarely or never used.

.WHY THIS MATTERS

    Unused indexes consume storage and increase
    write overhead.

.KEY METRICS

    user_seeks

    user_scans

    user_lookups

    user_updates

.HEALTHY

    Most indexes demonstrate usage activity.

.WARNING

    Zero seeks, scans and lookups with high updates.

.POSSIBLE CAUSES

    Legacy indexes.
    Application changes.
    Redundant indexing.

.NEXT ACTIONS

    Validate carefully before removal.

-------------------------------------------------------------------------------*/

SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    ISNULL(us.user_seeks,0) AS UserSeeks,
    ISNULL(us.user_scans,0) AS UserScans,
    ISNULL(us.user_lookups,0) AS UserLookups,
    ISNULL(us.user_updates,0) AS UserUpdates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
    AND i.index_id = us.index_id
    AND us.database_id = DB_ID()
WHERE i.index_id > 0
ORDER BY UserUpdates DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 3
    LOW VALUE INDEXES
-------------------------------------------------------------------------------

.PURPOSE

    Identify indexes with significantly more updates
    than reads.

.WHY THIS MATTERS

    Some indexes cost more to maintain than the
    benefit they provide.

.KEY METRICS

    Reads

    Updates

.HEALTHY

    Read activity is proportional to update cost.

.WARNING

    Updates greatly exceed total reads.

.POSSIBLE CAUSES

    Over-indexing.
    Legacy indexes.

.NEXT ACTIONS

    Review index usefulness.

-------------------------------------------------------------------------------*/

SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    ISNULL(us.user_seeks,0)
        + ISNULL(us.user_scans,0)
        + ISNULL(us.user_lookups,0) AS Reads,
    ISNULL(us.user_updates,0) AS Updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
    AND i.index_id = us.index_id
    AND us.database_id = DB_ID()
WHERE i.index_id > 0
ORDER BY Updates DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 4
    DUPLICATE INDEX DETECTION
-------------------------------------------------------------------------------

.PURPOSE

    Identify potentially duplicate indexes.

.WHY THIS MATTERS

    Duplicate indexes increase storage consumption,
    maintenance cost and write overhead.

.HEALTHY

    Minimal overlap between indexes.

.WARNING

    Multiple indexes sharing similar key definitions.

.POSSIBLE CAUSES

    Schema evolution.
    Multiple developers.
    Historical changes.

.NEXT ACTIONS

    Compare definitions before removal.

-------------------------------------------------------------------------------*/

SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.index_id,
    i.name,
    i.type_desc
FROM sys.indexes i
WHERE i.index_id > 0
ORDER BY OBJECT_NAME(i.object_id), i.name;

GO




/*-------------------------------------------------------------------------------
    SECTION 5
    FRAGMENTATION ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Review index fragmentation levels.

.WHY THIS MATTERS

    Fragmentation can increase I/O and reduce efficiency.

.KEY METRICS

    avg_fragmentation_in_percent

    page_count

.HEALTHY

    Less than 10 percent fragmentation.

.WARNING

    10 to 30 percent fragmentation.

.CRITICAL

    Greater than 30 percent fragmentation.

.NEXT ACTIONS

    Reorganize or rebuild according to maintenance strategy.

-------------------------------------------------------------------------------*/

SELECT
    OBJECT_NAME(ps.object_id) AS TableName,
    i.name,
    ps.index_type_desc,
    ps.page_count,
    ps.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    'LIMITED'
) ps
JOIN sys.indexes i
    ON ps.object_id = i.object_id
    AND ps.index_id = i.index_id
WHERE ps.index_id > 0
ORDER BY ps.avg_fragmentation_in_percent DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 6
    LARGEST INDEXES
-------------------------------------------------------------------------------

.PURPOSE

    Identify indexes consuming the most storage.

.WHY THIS MATTERS

    Large indexes have maintenance and storage costs.

.KEY METRICS

    ReservedMB

.HEALTHY

    Large indexes are justified by workload usage.

.WARNING

    Large indexes with little usage.

.POSSIBLE CAUSES

    Historical growth.
    Redundant indexing.

.NEXT ACTIONS

    Correlate with usage statistics.

-------------------------------------------------------------------------------*/

SELECT TOP (50)
    OBJECT_NAME(p.object_id) AS TableName,
    i.name AS IndexName,
    SUM(a.total_pages) * 8 / 1024 AS ReservedMB
FROM sys.partitions p
JOIN sys.allocation_units a
    ON p.partition_id = a.container_id
JOIN sys.indexes i
    ON p.object_id = i.object_id
    AND p.index_id = i.index_id
GROUP BY
    OBJECT_NAME(p.object_id),
    i.name
ORDER BY ReservedMB DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 7
    KEY LOOKUP INDICATORS
-------------------------------------------------------------------------------

.PURPOSE

    Identify indexes that may contribute to Key Lookups.

.WHY THIS MATTERS

    Excessive Key Lookups may result in high logical reads.

.KEY METRICS

    user_lookups

.HEALTHY

    Lookup activity remains moderate.

.WARNING

    High lookup counts.

.POSSIBLE CAUSES

    Missing INCLUDE columns.
    Incomplete covering indexes.

.NEXT ACTIONS

    Review execution plans.
    Evaluate covering indexes.

-------------------------------------------------------------------------------*/

SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    us.user_lookups
FROM sys.indexes i
JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
    AND i.index_id = us.index_id
WHERE us.database_id = DB_ID()
ORDER BY us.user_lookups DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 8
    INDEX USAGE ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Review overall index utilization.

.WHY THIS MATTERS

    Helps balance read performance versus maintenance costs.

.KEY METRICS

    Seeks

    Scans

    Lookups

    Updates

.HEALTHY

    Indexes provide measurable read value.

.WARNING

    High updates with limited read activity.

.NEXT ACTIONS

    Compare with Sections 2 and 3.

-------------------------------------------------------------------------------*/

SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name,
    ISNULL(us.user_seeks,0) AS Seeks,
    ISNULL(us.user_scans,0) AS Scans,
    ISNULL(us.user_lookups,0) AS Lookups,
    ISNULL(us.user_updates,0) AS Updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
    ON i.object_id = us.object_id
    AND i.index_id = us.index_id
    AND us.database_id = DB_ID()
WHERE i.index_id > 0
ORDER BY Seeks DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 9
    INDEX OPERATIONAL STATISTICS
-------------------------------------------------------------------------------

.PURPOSE

    Review operational activity affecting indexes.

.WHY THIS MATTERS

    Helps identify contention and workload patterns.

.KEY METRICS

    leaf_insert_count

    leaf_update_count

    leaf_delete_count

.HEALTHY

    Activity aligns with workload expectations.

.WARNING

    Excessive operational activity.

.POSSIBLE CAUSES

    Heavy OLTP workload.
    Frequent data modifications.

.NEXT ACTIONS

    Review indexing strategy.

-------------------------------------------------------------------------------*/

SELECT TOP (50)
    OBJECT_NAME(ios.object_id) AS TableName,
    i.name,
    ios.leaf_insert_count,
    ios.leaf_update_count,
    ios.leaf_delete_count,
    ios.page_latch_wait_count,
    ios.page_lock_wait_count
FROM sys.dm_db_index_operational_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL
) ios
JOIN sys.indexes i
    ON ios.object_id = i.object_id
    AND ios.index_id = i.index_id
ORDER BY ios.leaf_update_count DESC;

GO




/*-------------------------------------------------------------------------------
    SECTION 10
    EXECUTIVE SUMMARY
-------------------------------------------------------------------------------

.PURPOSE

    Provide a quick index health assessment.

.HEALTHY ENVIRONMENT

    Few missing index recommendations.

    Limited fragmentation.

    No excessive key lookups.

    Indexes actively used.

.INVESTIGATE

    High impact missing indexes.

    Unused indexes.

    Excessive fragmentation.

    High lookup activity.

    High update-to-read ratios.

.NEXT ACTIONS

    Missing Indexes:
        Review Section 1

    Unused Indexes:
        Review Sections 2 and 3

    Fragmentation:
        Review Section 5

    Key Lookups:
        Review Section 7

-------------------------------------------------------------------------------*/

SELECT

    (
        SELECT COUNT(*)
        FROM sys.dm_db_missing_index_details
    ) AS MissingIndexRecommendations,

    (
        SELECT COUNT(*)
        FROM sys.indexes
        WHERE index_id > 0
    ) AS TotalIndexes,

    (
        SELECT COUNT(*)
        FROM sys.dm_db_index_usage_stats
        WHERE database_id = DB_ID()
    ) AS IndexUsageRows;

GO




/******************************************************************************
FINAL DBA TRIAGE MATRIX
*******************************************************************************

MISSING INDEX ISSUE

INDICATORS

    High avg_user_impact

    High user_seeks

REVIEW

    Section 1

------------------------------------------------------------------------------
UNUSED INDEX ISSUE

INDICATORS

    High updates

    No seeks

    No scans

REVIEW

    Section 2

------------------------------------------------------------------------------
OVER-INDEXING ISSUE

INDICATORS

    Writes significantly exceed reads

REVIEW

    Section 3

------------------------------------------------------------------------------
DUPLICATE INDEX ISSUE

INDICATORS

    Similar index definitions

REVIEW

    Section 4

------------------------------------------------------------------------------
FRAGMENTATION ISSUE

INDICATORS

    avg_fragmentation_in_percent > 30

REVIEW

    Section 5

------------------------------------------------------------------------------
KEY LOOKUP ISSUE

INDICATORS

    High user_lookups

REVIEW

    Section 7

------------------------------------------------------------------------------
HIGH MAINTENANCE COST

INDICATORS

    High update counts

    Large indexes

REVIEW

    Sections 6, 8 and 9

------------------------------------------------------------------------------
QUERY PERFORMANCE ISSUE

INDICATORS

    High reads

    High CPU

    Missing indexes

REVIEW

    Health Query Performance Toolkit

******************************************************************************
END OF INDEX HEALTH CHECK
******************************************************************************/