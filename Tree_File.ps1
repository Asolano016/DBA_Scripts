Clear-Host
$RootPath = "C:\Users\asolanoa\OneDrive - DPDHL\DBA\01_GitRepositories\DBA_Scripts\03_Administration"

function Show-Tree {
    param (
        [string]$Path,
        [string]$Indent = ""
    )

    Get-ChildItem -Path $Path -Directory | Sort-Object Name | ForEach-Object {
        Write-Output "$Indent|-- [$($_.Name)]"
        Show-Tree -Path $_.FullName -Indent "$Indent|   "
    }

    Get-ChildItem -Path $Path -File | Sort-Object Name | ForEach-Object {
        Write-Output "$Indent|-- $($_.Name)"
    }
}

# Mostrar la carpeta raíz
Write-Output "[$(Split-Path $RootPath -Leaf)]"

Show-Tree -Path $RootPath -Indent ""