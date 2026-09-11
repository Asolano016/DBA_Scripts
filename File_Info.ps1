Clear-Host
$Folder = "C:\Users\asolanoa\OneDrive - DPDHL\DBA\01_GitRepositories\DBA_Scripts\01_Monitoring\04_Health"

Get-ChildItem -Path $Folder -File | ForEach-Object {

    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Archivo: $($_.Name)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Yellow

    Get-Content $_.FullName

    Write-Host "`n"
}