/******************************************************************************
SSISDB RETENTION WINDOW MANAGEMENT
-------------------------------------------------------------------------------

PURPOSE

    Reduce SSISDB retention period and purge historical execution data.

WHY THIS MATTERS

    The SSIS Catalog (SSISDB) stores:

        - Package execution history
        - Operation logs
        - Validation results
        - Execution reports
        - Environment operation history

    Over time, SSISDB can grow significantly and may consume large
    amounts of storage.

WHAT THIS SCRIPT DOES

    Step 1
    -------
    Changes the SSISDB retention window.

    Current retained data older than:

        RETENTION_WINDOW = 180 days

    becomes eligible for cleanup.

    Step 2
    -------
    Displays current catalog properties.

    Step 3
    -------
    Executes the SSISDB cleanup procedure.

IMPORTANT

    This operation permanently removes historical SSIS execution data.

    Review retention requirements before execution.

WHEN TO USE

    - SSISDB is growing excessively.
    - Storage consumption needs to be reduced.
    - Old execution history is no longer required.
    - Retention policy has changed.

PRE-CHECKS

    Review current SSISDB size.

    Review current retention settings.

    Confirm business retention requirements.

POST-CHECKS

    Validate SSIS package execution history.
    Verify available disk space.
    Monitor cleanup duration.

EXPECTED IMPACT

    - Reduction in SSISDB size.
    - Reduction in backup size.
    - Reduction in maintenance overhead.

******************************************************************************/

USE SSISDB;
GO

-------------------------------------------------------------------------------
-- STEP 1
-- REVIEW CURRENT CONFIGURATION
-------------------------------------------------------------------------------

SELECT *
FROM [catalog].catalog_properties;
GO

-------------------------------------------------------------------------------
-- STEP 2
-- UPDATE RETENTION WINDOW
-------------------------------------------------------------------------------
-- Retain X days of SSIS execution history.
-------------------------------------------------------------------------------

EXEC [catalog].configure_catalog
    @property_name = 'RETENTION_WINDOW',
    @property_value = 180;
GO

-------------------------------------------------------------------------------
-- STEP 3
-- EXECUTE CLEANUP
-------------------------------------------------------------------------------
-- Removes records older than the configured retention window.
-------------------------------------------------------------------------------

EXEC [internal].[cleanup_server_retention_window];
GO