$RootSource = "C:\Users\asolanoa\OneDrive - DPDHL\DBA\02_Scripts - Copy"
$RootTarget = "C:\Users\asolanoa\OneDrive - DPDHL\DBA\01_GitRepositories\DBA_Scripts"

$Mappings = @{

    "01_Monitoring" = @(
        "Blocking Deadlocks Transaction.sql",
        "Blocking.sql",
        "Check Current Transactions per Databases.sql",
        "Check Database Files Size.sql",
        "Check database free and used space.sql",
        "Check databases file used and free space.sql",
        "Check In Recovery DB Progress.sql",
        "Check Memory Usage.sql",
        "Check Open Sessions Text.sql",
        "Check Reindexing Progress.sql",
        "Check Total Databases Size.sql",
        "CheckDatabaseFileSpaceStats.sql",
        "CheckDatabaseFileSpaceStats_Instance.sql",
        "CheckDatabaseSpaceSummary_Instance.sql",
        "Database File Info.sql",
        "Database Recovery Phase.sql",
        "Drive Space Tsql.sql",
        "Filter MSSQL Log.sql",
        "Filter SP_WHO2.sql",
        "Head Blocker.sql",
        "Head Blocker Tauhid.sql",
        "High CPU Usage.sql",
        "High Memory Usage.sql",
        "Instance FQDN.sql",
        "LongRunningQuerie.sql",
        "Monitoring Sessions.sql",
        "Patching issues.sql",
        "Query Text from Query Stored.sql",
        "Schema_Change_History.sql",
        "Search database object.sql",
        "Shrink Check.sql",
        "TLOG Usage.sql"
    )

    "02_Performance" = @(
        "Cost Threshold Parellelism.sql",
        "MAXDOP.sql",
        "MAXDOP Suggestion.sql",
        "MissingIndexes.sql",
        "Index Fragmentation.sql",
        "MASTER_TUNING_SCRIPTS.sql",
        "MASTER_TUNING_SCRIPTS_II.sql"
    )

    "03_Administration" = @(
        "Change All Databases Compatibility Level.sql",
        "Change database owner.sql",
        "Change recovery model.sql",
        "Check Custome Role.sql",
        "Check Database Info.sql",
        "Check dbmail configurations.sql",
        "Create Alter Recovery Model Scripts.sql",
        "Create Mail Profile and Account.sql",
        "Database Size.sql",
        "Detach - Attach script.sql",
        "fn_dblog.sql",
        "Generate CI name.sql",
        "GenShrinkScriptv1.sql",
        "Kill Inactive Sessions.sql",
        "Reduce SSISDB Retention Windows.sql",
        "Search specific string in an object.sql",
        "Shrink All User Database Transaction Log.sql",
        "Shrink Size Info.sql",
        "Shrink Size Info (Jiri).sql",
        "Table Sizes.sql",
        "MASTER_SERVER_INFO.SQL",
        "Master_Server_Permissions.sql"
    )

    "04_Backup-Restore" = @(
        "Backup and Restore.sql",
        "Backup History.sql",
        "Backup History Lite.sql",
        "Restore History.sql",
        "Restore Histoy Lite.sql",
        "Backup Necessary Databases.sql",
        "Backup All User Databases.sql",
        "Backup Specific Database User Access.sql",
        "Generate Restore Script Sequence.sql",
        "Restore Script (One File).sql",
        "Last Full Backups Size.sql",
        "Check logs backup sequence.sql",
        "Monitoring Backup and  Restore Process.sql",
        "Successful Restore Operations.sql",
        "Create Backups Scripts (4 FILE EACH).sql",
        "Create Restore Scripts (4 FILE EACH).sql",
        "Create Backup for Test.sql",
        "Restore for Test.sql"
    )

    "05_Security" = @(
        "All Database Access.sql",
        "All Database Access 2.sql",
        "All Instance Access.sql",
        "Backup Access.sql",
        "Check AD Group Members.sql",
        "Check and Fix Orphaned Users.sql",
        "Check Databases Users and Roles.sql",
        "Check if GRANT EXECUTE.sql",
        "Check Instance-Level Roles.sql",
        "Check Login Roles.sql",
        "Check securables - sp_helprotect.sql",
        "Check User Access for All Databases.sql",
        "Check User Securables.sql",
        "Create pasword for list of users.sql",
        "Create READ, WRITE, EXECUTE GROUP.sql",
        "DB User Access Template.sql",
        "Grant OU Access.sql",
        "Link Logins For Each Databases.sql",
        "Migrate Logins.sql",
        "OAT_Check Users.sql",
        "SQL Login Hashed Password.sql",
        "Super PAR OAT Check Users.sql",
        "Login Database Roles.sql",
        "Login Instance Roles.sql",
        "Check Standard PAR Access.sql",
        "Check Non-Standard PAR Access.sql"
    )

    "06_SQL Agent" = @(
        "Add Operator Notification to Job.sql",
        "Check job and schedule owners.sql",
        "Check Jobs Proxies.sql",
        "Check Proxies and Credentials.sql",
        "Create schedule for multiple jobs.sql",
        "Enable and Disable Jobs.sql",
        "Jobs Data.sql",
        "Jobs Schedules.sql",
        "Jobs Subsystem Category.sql",
        "Last Job Execution.sql"
    )

    "07_High Availability" = @(
        "AlwaysOn_Add_DB.sql",
        "AlwaysON_Queries.sql",
        "Change AG Owner.sql",
        "LastCommitReplicationLag.sql",
        "ReplicationLag.sql"
    )

    "08_Automation (PowerShell)" = @(
        "*.ps1",
        "*.cmd",
        "*.json"
    )

    "09_Customer Specific" = @(
        "PAR_DROP.sql",
        "PAR_Insert.sql",
        "PAR_MANUAL_PROCESS.sql",
        "PAR_PROCESSv5.sql",
        "PAR_PROCESS_Andrés.sql",
        "PAR_TAR_Queryv1.sql",
        "CW AO Check.sql",
        "Ghost Patching Review.sql",
        "Check Custome Roles.sql",
        "DACS Accesses Review.sql",
        "DACS Accounts Backup.sql",
        "DACS Accounts Removal.sql",
        "DACS Data Check.sql",
        "Check Enable Monitoring.sql",
        "Connection String.sql",
        "Check Monitoring Log.sql",
        "Update PARAudit monitoring schedule.sql",
        "Update PAR Automation Dates.sql",
        "Check instance or host info.sql",
        "Check SQLInventory Log.sql",
        "Check EventDDL.sql"
    )
}

foreach ($Category in $Mappings.Keys) {

    $Destination = Join-Path $RootTarget $Category

    foreach ($Pattern in $Mappings[$Category]) {

        Get-ChildItem -Path $RootSource -Recurse -File -Filter $Pattern -ErrorAction SilentlyContinue | ForEach-Object {

            Write-Host "Moving $($_.Name) -> $Category" -ForegroundColor Green

            # VALIDACIÓN INICIAL
            #Copy-Item $_.FullName -Destination $Destination -Force

            # CUANDO VALIDE TODO:
            Move-Item $_.FullName -Destination $Destination -Force
        }
    }
}