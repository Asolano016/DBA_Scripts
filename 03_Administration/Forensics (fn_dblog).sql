/******************************************************************************
SQL SERVER TRANSACTION LOG FORENSICS (fn_dblog)
-------------------------------------------------------------------------------

PURPOSE

    Investigate transactional activity recorded in the active portion
    of the SQL Server Transaction Log.

COMMON USE CASES

    • Who deleted data?
    • Who updated data?
    • Was a TRUNCATE executed?
    • Was an object dropped?
    • What happened during a transaction?
    • What was the sequence of [Operation]s?

IMPORTANT

    fn_dblog() is undocumented.

    Use for investigation and troubleshooting purposes only.

    Large unrestricted scans may be expensive.

******************************************************************************/

--------------------------------------------------------------------------------
-- SECTION 1
-- RECENT TRANSACTIONS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Show recently started transactions.
--
--------------------------------------------------------------------------------

SELECT TOP (100) [Current LSN]
	,[Transaction ID]
	,[Transaction Name]
	,[Begin Time] 
    ,[Operation]
FROM fn_dblog(NULL,NULL)
WHERE [Operation] = 'LOP_BEGIN_XACT'
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 2
-- DELETE INVESTIGATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Find recently deleted rows.
--
--------------------------------------------------------------------------------

SELECT TOP (200) [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[Transaction Name] 
    ,[Operation] 
    ,[Context] 
    ,[AllocUnitName]

FROM fn_dblog(NULL,NULL)
WHERE [Operation] = 'LOP_DELETE_ROWS'
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 3
-- UPDATE INVESTIGATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Find row modifications.
--
--------------------------------------------------------------------------------

SELECT TOP (200) [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[Transaction Name] 
    ,[Operation] 
    ,[Context] 
    ,[AllocUnitName]

FROM fn_dblog(NULL,NULL)

WHERE [Operation] IN ('LOP_MODIFY_ROW', 'LOP_MODIFY_COLUMNS')
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 4
-- INSERT INVESTIGATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Find inserted rows.
--
--------------------------------------------------------------------------------

SELECT TOP (200) [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[Transaction Name] 
    ,[Operation] 
    ,[Context] 
    ,[AllocUnitName]
FROM fn_dblog(NULL,NULL)
WHERE [Operation] = 'LOP_INSERT_ROWS'
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 5
-- TRUNCATE TABLE INVESTIGATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Detect potential TRUNCATE TABLE activity.
--
-- NOTE
--
--     TRUNCATE does not log individual row deletes.
--
--------------------------------------------------------------------------------

SELECT TOP (200) [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[Transaction Name] 
    ,[Operation] 
    ,[Context] 
    ,[AllocUnitName]
FROM fn_dblog(NULL,NULL)
WHERE [Operation] IN ('LOP_DEALLOCATE_EXTENT', 'LOP_FORMAT_PAGE')
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 6
-- DDL INVESTIGATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review object level changes.
--
-- EXAMPLES
--
--     DROP TABLE
--     CREATE TABLE
--     ALTER TABLE
--     CREATE INDEX
--
--------------------------------------------------------------------------------

SELECT TOP (200) [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[Transaction Name] 
    ,[Operation] 
    ,[Context]
FROM fn_dblog(NULL,NULL)
WHERE [Transaction Name] IN ('DROPOBJ', 'CREATE INDEX', 'ALTER TABLE', 'CREATE TABLE')
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 7
-- FAILED / ROLLED BACK TRANSACTIONS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Identify aborted transactions.
--
--------------------------------------------------------------------------------

SELECT TOP (100) [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[End Time]
	,[Transaction Name] 
    ,[Operation]
FROM fn_dblog(NULL,NULL)
WHERE [Operation] = 'LOP_ABORT_XACT'
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 8
-- COMMITTED TRANSACTIONS
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review successfully committed transactions.
--
--------------------------------------------------------------------------------

SELECT TOP (100) [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[End Time]
	,[Transaction Name] 
    ,[Operation]
FROM fn_dblog(NULL,NULL)
WHERE [Operation] = 'LOP_COMMIT_XACT'
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 9
-- DATA CHANGE INVESTIGATION
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Review INSERT, UPDATE and DELETE activity together.
--
-- USAGE
--
--     Best starting point when users report:
--
--     "Data changed unexpectedly"
--
--------------------------------------------------------------------------------

SELECT TOP (500) [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[End Time]
	,[Transaction Name] 
    ,[Operation] 
    ,[Context] 
    ,[AllocUnitName]
FROM fn_dblog(NULL,NULL)
WHERE [Operation] IN ('LOP_INSERT_ROWS', 'LOP_DELETE_ROWS', 'LOP_MODIFY_ROW', 'LOP_MODIFY_COLUMNS')
ORDER BY [Current LSN] DESC;
GO

--------------------------------------------------------------------------------
-- SECTION 10
-- TRANSACTION TIMELINE
--------------------------------------------------------------------------------
--
-- PURPOSE
--
--     Reconstruct a specific transaction.
--
-- USAGE
--
--     1. Obtain Transaction ID from previous sections.
--     2. Replace value below.
--
--------------------------------------------------------------------------------

DECLARE @TransactionID NVARCHAR(50);

SET @TransactionID = '0000:00000000';

SELECT [Current LSN]
	,[Transaction ID]
	,[Begin Time]
	,[End Time]
	,[Transaction Name] 
    ,[Operation] 
    ,[Context] 
    ,[AllocUnitName]
FROM fn_dblog(NULL,NULL)
WHERE [Transaction ID] = @TransactionID
ORDER BY [Current LSN];
GO

/******************************************************************************
QUICK REFERENCE
-------------------------------------------------------------------------------

LOP_BEGIN_XACT

    Transaction started.

LOP_COMMIT_XACT

    Transaction committed successfully.

LOP_ABORT_XACT

    Transaction rolled back.

LOP_INSERT_ROWS

    Row inserted.

LOP_DELETE_ROWS

    Row deleted.

LOP_MODIFY_ROW

    Row updated.

LOP_MODIFY_COLUMNS

    Column level modification.

LOP_DEALLOCATE_EXTENT

    Commonly associated with TRUNCATE activity.

-------------------------------------------------------------------------------

TYPICAL INVESTIGATION FLOW

Data Deleted

    Section 2
        ->
    Capture Transaction ID
        ->
    Section 10

Data Updated

    Section 3
        ->
    Capture Transaction ID
        ->
    Section 10

Data Truncated

    Section 5
        ->
    Capture Transaction ID
        ->
    Section 10

Object Dropped

    Section 6
        ->
    Capture Transaction ID
        ->
    Section 10

******************************************************************************/