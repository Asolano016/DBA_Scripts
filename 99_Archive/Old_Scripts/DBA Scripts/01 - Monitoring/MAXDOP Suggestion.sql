-- Get the number of logical processors
DECLARE @LogicalProcessors INT;
SET @LogicalProcessors = (SELECT COUNT(*) FROM sys.dm_os_schedulers WHERE status = 'VISIBLE ONLINE');

-- Suggest MAXDOP configuration
DECLARE @SuggestedMAXDOP INT;

IF @LogicalProcessors = 1
BEGIN
    SET @SuggestedMAXDOP = 1; -- Single processor
END
ELSE IF @LogicalProcessors BETWEEN 2 AND 4
BEGIN
    SET @SuggestedMAXDOP = @LogicalProcessors; -- Use all available processors
END
ELSE IF @LogicalProcessors BETWEEN 5 AND 8
BEGIN
    SET @SuggestedMAXDOP = 4; -- Recommended to limit to 4
END
ELSE IF @LogicalProcessors BETWEEN 9 AND 16
BEGIN
    SET @SuggestedMAXDOP = 8; -- Recommended to limit to 8
END
ELSE
BEGIN
    SET @SuggestedMAXDOP = 16; -- For more than 16 processors, limit to 16
END

-- Output the suggested MAXDOP
SELECT @LogicalProcessors AS NumberOfLogicalProcessors, @SuggestedMAXDOP AS SuggestedMAXDOP;