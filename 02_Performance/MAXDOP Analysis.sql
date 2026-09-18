/******************************************************************************
MAXDOP RECOMMENDATION ANALYZER
-------------------------------------------------------------------------------
.PURPOSE

    Analyze server CPU topology and provide a recommended MAXDOP value.

.OUTPUT

    - Logical CPUs
    - Physical Cores
    - NUMA Nodes
    - CPUs per NUMA Node
    - Current MAXDOP
    - Current Cost Threshold for Parallelism
    - Recommended MAXDOP

.REFERENCE GUIDELINE

    CPUs per NUMA <= 8
        MAXDOP = CPUs per NUMA

    CPUs per NUMA > 8
        MAXDOP = 8

******************************************************************************/

SET NOCOUNT ON;

DECLARE @CurrentMAXDOP INT;
DECLARE @CurrentCTFP INT;

SELECT
    @CurrentMAXDOP = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'max degree of parallelism';

SELECT
    @CurrentCTFP = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'cost threshold for parallelism';

;WITH NUMAInfo AS
(
    SELECT
        parent_node_id,
        COUNT(*) AS LogicalCPUsPerNUMA
    FROM sys.dm_os_schedulers
    WHERE status = 'VISIBLE ONLINE'
      AND parent_node_id < 64
    GROUP BY parent_node_id
),
Summary AS
(
    SELECT
        MAX(LogicalCPUsPerNUMA) AS MaxLogicalCPUsPerNUMA,
        COUNT(*) AS NUMANodes
    FROM NUMAInfo
)
SELECT

    GETDATE() AS CaptureTime,

    si.cpu_count AS LogicalCPUs,

    si.hyperthread_ratio AS HyperthreadRatio,

    CASE
        WHEN si.hyperthread_ratio > 0
        THEN si.cpu_count / si.hyperthread_ratio
        ELSE NULL
    END AS PhysicalCores,

    s.NUMANodes,

    s.MaxLogicalCPUsPerNUMA AS CPUsPerNUMANode,

    @CurrentMAXDOP AS CurrentMAXDOP,

    @CurrentCTFP AS CurrentCostThresholdForParallelism,

    CASE
        WHEN s.MaxLogicalCPUsPerNUMA <= 8
            THEN s.MaxLogicalCPUsPerNUMA
        ELSE 8
    END AS RecommendedMAXDOP,

    CASE
        WHEN @CurrentMAXDOP =
            CASE
                WHEN s.MaxLogicalCPUsPerNUMA <= 8
                    THEN s.MaxLogicalCPUsPerNUMA
                ELSE 8
            END
        THEN 'MAXDOP configuration appears aligned with recommendation'
        WHEN @CurrentMAXDOP <
            CASE
                WHEN s.MaxLogicalCPUsPerNUMA <= 8
                    THEN s.MaxLogicalCPUsPerNUMA
                ELSE 8
            END
        THEN 'MAXDOP is lower than recommendation'
        ELSE 'MAXDOP is higher than recommendation'
    END AS Assessment

FROM sys.dm_os_sys_info si
CROSS JOIN Summary s;

GO

/******************************************************************************
NUMA NODE DETAILS
******************************************************************************/

SELECT
    parent_node_id AS NUMANode,
    COUNT(*) AS LogicalCPUsPerNUMA
FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE'
  AND parent_node_id < 64
GROUP BY parent_node_id
ORDER BY parent_node_id;

GO

/******************************************************************************
CONFIGURATION REVIEW
******************************************************************************/

SELECT
    name,
    value_in_use
FROM sys.configurations
WHERE name IN
(
    'max degree of parallelism',
    'cost threshold for parallelism'
);

GO

/******************************************************************************
DBA INTERPRETATION GUIDE

Example 1

    CPUsPerNUMANode = 4

    Recommended MAXDOP = 4

------------------------------------------------------------------------------

Example 2

    CPUsPerNUMANode = 8

    Recommended MAXDOP = 8

------------------------------------------------------------------------------

Example 3

    CPUsPerNUMANode = 16

    Recommended MAXDOP = 8

------------------------------------------------------------------------------

Example 4

    CPUsPerNUMANode = 32

    Recommended MAXDOP = 8

------------------------------------------------------------------------------

ALWAYS VALIDATE WITH

    - CXPACKET waits
    - CXCONSUMER waits
    - Runnable tasks
    - Workload characteristics

MAXDOP SHOULD NOT BE CHANGED BASED SOLELY ON CPU COUNT.

******************************************************************************
END OF FILE
******************************************************************************/