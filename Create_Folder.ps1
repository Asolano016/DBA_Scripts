$folderName = @("01_Monitoring"
"02_Performance"
"03_Administration"
"04_Backup-Restore"
"05_Security"
"06_SQL Agent"
"07_High Availability"
"08_Automation (PowerShell)"
"09_Customer Specific"
"10_Archive")

$path = Get-Location

foreach ($folder in $folderName) {
    $new = Join-Path -Path $path -ChildPath $folder
    New-Item -Path "$new" -ItemType Directory
}

#New-Item -Path "C:\path\to\your\NewFolder" -ItemType Directory


