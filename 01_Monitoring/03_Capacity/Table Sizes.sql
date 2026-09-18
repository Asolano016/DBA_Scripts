/*-------------------------------------------------------------------------------
    LARGEST TABLES ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Identify the largest tables within the current database and understand
    how space is consumed.

.WHY THIS MATTERS

    Large tables are commonly associated with:

        • Database growth
        • Storage consumption
        • Backup duration increases
        • Index maintenance overhead
        • Query performance issues
        • Capacity planning initiatives

    This report helps DBAs quickly identify the primary space consumers
    within a database.

.KEY METRICS

    SchemaName

        Schema owning the table.

    TableName

        Table name.

    ObjectId

        Internal SQL Server object identifier.

    RowCount

        Approximate number of rows stored in the table.

        Useful for understanding table density and growth.

    TotalSpaceMB

        Total space reserved by the table.

        Includes:

            Data
            Indexes
            Internal overhead

    UsedSpaceMB

        Space currently used by the table.

    DataSpaceMB

        Space used by actual table data.

    IndexAndOverheadMB

        Space consumed by:

            Clustered indexes
            Nonclustered indexes
            Internal allocation structures

        Calculated as:

            UsedSpaceMB - DataSpaceMB

    AvgRowSizeBytes

        Average size of a row in bytes.

        Calculated using:

            DataSpaceMB / RowCount

        Useful for detecting:

            Wide rows
            VARCHAR(MAX) abuse
            XML storage
            JSON storage
            Excessive column growth

    PctOfDatabase

        Percentage of total database space consumed
        by the table.

        Useful for quickly identifying major storage consumers.

    TableSizeCategory

        Small
            Less than 1 GB

        Medium
            Between 1 GB and 10 GB

        Large
            Greater than 10 GB

.HOW TO INTERPRET

    CASE 1

        High DataSpaceMB
        High RowCount
        Reasonable AvgRowSizeBytes

    Interpretation

        Large table due to volume of data.

        Normal growth pattern.

------------------------------------------------------------------------------
    CASE 2

        High DataSpaceMB
        Low RowCount
        Very High AvgRowSizeBytes

    Interpretation

        Wide rows.

        Investigate:

            VARCHAR(MAX)
            NVARCHAR(MAX)
            XML
            JSON
            Large text columns

------------------------------------------------------------------------------
    CASE 3

        IndexAndOverheadMB
        Greater than DataSpaceMB

    Interpretation

        Indexes consume more space than actual data.

        Investigate:

            Duplicate indexes
            Unused indexes
            Over-indexing

        Review:

            Health Index Toolkit

------------------------------------------------------------------------------
    CASE 4

        PctOfDatabase > 30%

    Interpretation

        Table is a major database storage consumer.

        Consider:

            Archiving strategies
            Partitioning
            Data retention policies

------------------------------------------------------------------------------
    CASE 5

        Very High RowCount
        Small AvgRowSizeBytes

    Interpretation

        Potential candidate for:

            Partitioning
            Archive strategies
            Tiered storage

.RECOMMENDED REVIEW PROCESS

    Step 1

        Sort by DataSpaceMB.

------------------------------------------------------------------------------
    Step 2

        Review top 10 largest tables.

------------------------------------------------------------------------------
    Step 3

        Review PctOfDatabase.

------------------------------------------------------------------------------
    Step 4

        Review AvgRowSizeBytes.

------------------------------------------------------------------------------
    Step 5

        Review IndexAndOverheadMB.

------------------------------------------------------------------------------
    Step 6

        Correlate findings with:

            Health Index Toolkit

            Health Query Performance Toolkit

            Capacity Planning Reports

.COMMON USE CASES

    Capacity Planning

        Identify largest storage consumers.

------------------------------------------------------------------------------
    Backup Optimization

        Understand databases driving backup sizes.

------------------------------------------------------------------------------
    Archiving Projects

        Locate archive candidates.

------------------------------------------------------------------------------
    Index Reviews

        Identify tables with excessive index overhead.

------------------------------------------------------------------------------
    Database Growth Reviews

        Determine which tables are responsible
        for growth over time.

.NOTES

    Only user tables are included.

    Tables smaller than 100 MB are excluded
    to reduce noise.

    The report focuses on meaningful storage consumers.

.RELATED SCRIPTS

    Health Index Toolkit

    Health Query Performance Toolkit

    Shrink Opportunity Analysis

    Database Growth Analysis

-------------------------------------------------------------------------------*/

SELECT s.name AS SchemaName
      ,t.name AS TableName
      ,t.object_id AS ObjectId
      ,MAX(p.rows) AS [RowCount]
      ,(SUM(a.total_pages) * 8) / 1024 AS TotalSpaceMB
      ,(SUM(a.used_pages) * 8) / 1024 AS UsedSpaceMB
      ,(SUM(a.data_pages) * 8) / 1024 AS DataSpaceMB
      ,((SUM(a.used_pages) - SUM(a.data_pages)) * 8) / 1024 AS IndexAndOverheadMB
      ,CASE 
            WHEN MAX(p.rows) = 0THEN 0 
            ELSE CAST ((SUM(a.data_pages) * 8.0 * 1024) / MAX(p.rows) AS decimal(18,2))
       END AS AvgRowSizeBytes
      ,CAST(100.0 * (SUM(a.total_pages) * 8 / 1024.0) / SUM(SUM(a.total_pages) * 8 / 1024.0) OVER () AS decimal(10,2)) AS PctOfDatabase
      ,CASE 
            WHEN (SUM(a.total_pages) * 8) / 1024 < 1024 THEN 'Small'
            WHEN (SUM(a.total_pages) * 8) / 1024 < 10240 THEN 'Medium'
            ELSE 'Large'
       END AS TableSizeCategory
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE i.index_id <= 1
AND t.is_ms_shipped = 0
GROUP BY s.name, t.name, t.object_id
HAVING (SUM(a.data_pages) * 8) / 1024 > 100
ORDER BY DataSpaceMB DESC;
