$Root = "C:\Users\asolanoa\OneDrive - DPDHL\DBA\01_GitRepositories\DBA_Scripts\01_Monitoring"

$Map = @{
    "Blocking" = @(
        "Blocking Deadlocks Transaction.sql",
        "Blocking.sql",
        "Head Blocker.sql",
        "Head Blocker Tauhid.sql",
        "Filter SP_WHO2.sql"
    )

    "Capacity" = @(
        "Check Database Files Size.sql",
        "Check database free and used space.sql",
        "Check databases file used and free space.sql",
        "Check Total Databases Size.sql",
        "CheckDatabaseFileSpaceStats.sql",
        "CheckDatabaseFileSpaceStats_Instance.sql",
        "CheckDatabaseSpaceSummary_Instance.sql",
        "Database File Info.sql",
        "Drive Space Tsql.sql",
        "Shrink Check.sql",
        "TLOG Usage.sql"
    )

    "Queries" = @(
        "Check Current Transactions per Databases.sql",
        "Check Open Sessions Text.sql",
        "LongRunningQuerie.sql",
        "Monitoring Sessions.sql",
        "Query Text from Query Stored.sql",
        "Search database object.sql"
    )

    "Recovery" = @(
        "Check In Recovery DB Progress.sql",
        "Check Reindexing Progress.sql",
        "Database Recovery Phase.sql"
    )

    "Health" = @(
        "Check Memory Usage.sql",
        "Filter MSSQL Log.sql",
        "High CPU Usage.sql",
        "High Memory Usage.sql",
        "Instance FQDN.sql",
        "Patching issues.sql",
        "Schema_Change_History.sql"
    )
}

foreach ($Folder in $Map.Keys) {

    $Destination = Join-Path $Root $Folder

    foreach ($File in $Map[$Folder]) {

        $SourceFile = Join-Path $Root $File

        if (Test-Path $SourceFile) {
            Move-Item $SourceFile $Destination -Force
            Write-Host "Moved $File -> $Folder" -ForegroundColor Green
        }
        else {
            Write-Warning "$File not found"
        }
    }
}