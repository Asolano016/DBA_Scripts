/*-------------------------------------------------------------------------------
    PARALLELISM COST THRESHOLD ANALYSIS
-------------------------------------------------------------------------------

.PURPOSE

    Analyze cached parallel execution plans and their estimated
    Statement SubTree Cost values.

.WHY THIS MATTERS

    SQL Server evaluates parallel execution plans only when the
    estimated cost of the best serial plan exceeds the current
    Cost Threshold for Parallelism (CTFP) setting.

    This analysis helps determine whether the current CTFP value
    is too low or too high for the workload.

.KEY METRICS

    ParallelPlans

        Total number of cached plans containing a Parallelism operator.

    MinCost

        Lowest StatementSubTreeCost observed among parallel plans.

    AvgCost

        Average StatementSubTreeCost of parallel plans.

    MaxCost

        Highest StatementSubTreeCost found in cache.

    P50

        Median cost of parallel plans.

    P75

        Cost below which 75 percent of parallel plans fall.

    P90

        Cost below which 90 percent of parallel plans fall.

    P95

        Cost below which 95 percent of parallel plans fall.

.HOW IT WORKS

    The script scans the SQL Server Plan Cache and extracts
    execution plans containing Parallelism operators.

    It reads the StatementSubTreeCost attribute from the XML plan
    and performs statistical analysis on the resulting dataset.

    This allows DBAs to understand the cost range where
    SQL Server is currently choosing parallel execution.

.HEALTHY

    Parallel plans are typically associated with genuinely
    expensive statements.

    Median and upper percentile costs are substantially higher
    than the current Cost Threshold for Parallelism setting.

.WARNING

    Large numbers of parallel plans with low StatementSubTreeCost
    values may indicate that Cost Threshold for Parallelism
    is configured too low.

.EXAMPLE

    Current CTFP = 5

    P50 = 8
    P75 = 11
    P90 = 14

    Interpretation:

        Many relatively inexpensive queries qualify for
        parallel execution.

        CTFP may be lower than necessary.

.EXAMPLE

    Current CTFP = 5

    P50 = 45
    P75 = 70
    P90 = 120

    Interpretation:

        Parallelism is generally reserved for expensive queries.

        Current CTFP may already be appropriate.

.POSSIBLE CAUSES OF LOW COST PARALLELISM

    Cost Threshold configured too low.

    OLTP workload with many moderately expensive queries.

    Excessive parallel plan generation.

    Legacy server configuration.

.POSSIBLE CAUSES OF HIGH COST PARALLELISM

    Reporting workload.

    Data warehouse workload.

    Large analytical queries.

    Existing high Cost Threshold configuration.

.NEXT ACTIONS

    Review current configuration:

        EXEC sp_configure 'cost threshold for parallelism';

    Compare:

        Current CTFP
        P50
        P75
        P90
        P95

    Consider gradual increases only.

    Evaluate:

        CPU utilization
        SOS_SCHEDULER_YIELD waits
        CXPACKET waits
        CXCONSUMER waits
        Runnable task counts

.IMPORTANT NOTES

    StatementSubTreeCost is an estimated optimizer cost.

    It does not represent actual runtime or actual CPU usage.

    This analysis should be used as guidance and not as the sole
    criterion for changing Cost Threshold for Parallelism.

    Any configuration changes should be tested and observed over
    a full business cycle before additional adjustments are made.

.COMMON INTERPRETATION GUIDELINES

    P50 < 10

        Strong indication that many inexpensive queries are
        receiving parallel plans.

        Investigate raising CTFP.

    P50 between 10 and 30

        Common for mixed OLTP workloads.

        Additional investigation recommended.

    P50 between 30 and 50

        Frequently observed in healthy OLTP systems.

    P50 > 50

        Parallelism is generally restricted to expensive queries.

        Usually not an indication that CTFP needs to be increased.

-------------------------------------------------------------------------------*/

;WITH XMLNAMESPACES
(
    DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
),
ParallelPlans AS
(
    SELECT
        CAST
        (
            n.value
            (
                '(@StatementSubTreeCost)[1]',
                'float'
            )
            AS decimal(18,2)
        ) AS StatementCost
    FROM sys.dm_exec_cached_plans ecp
    CROSS APPLY sys.dm_exec_query_plan(ecp.plan_handle) eqp
    CROSS APPLY query_plan.nodes
    (
        '/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple'
    ) qn(n)
    WHERE n.query('.').exist('//RelOp[@PhysicalOp="Parallelism"]') = 1
)
SELECT
    COUNT(*) AS ParallelPlans,
    MIN(StatementCost) AS MinCost,
    AVG(StatementCost) AS AvgCost,
    MAX(StatementCost) AS MaxCost
FROM ParallelPlans;

-------------------------------------------------------------------------------

;WITH XMLNAMESPACES
(
    DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
),
ParallelPlans AS
(
    SELECT
        CAST
        (
            n.value
            (
                '(@StatementSubTreeCost)[1]',
                'float'
            )
            AS decimal(18,2)
        ) AS StatementCost
    FROM sys.dm_exec_cached_plans ecp
    CROSS APPLY sys.dm_exec_query_plan(ecp.plan_handle) eqp
    CROSS APPLY query_plan.nodes
    (
        '/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple'
    ) qn(n)
    WHERE n.query('.').exist('//RelOp[@PhysicalOp="Parallelism"]') = 1
)
SELECT DISTINCT
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY StatementCost) OVER() AS P50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY StatementCost) OVER() AS P75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY StatementCost) OVER() AS P90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY StatementCost) OVER() AS P95
FROM ParallelPlans;