#findstr "AndresTest" "D:\01_Dev\Andr�s\*.*"

#findstr "db_full_sql03" "C:\Program Files\VERITAS\NetBackup\DbExt\MsSql\*.*"

findstr "CHARINDEX" "C:\Users\asolanoa\OneDrive - DPDHL\DBA\Scripts\*.*" /OFFLINE

findstr "RevokeSysadminFunc" "D:\00_Master_Prod\*.*" 

Get-ChildItem -Path "D:\00_Master_Prod\" -Recurse | 
    Select-String -Pattern "RevokeSysadminFunc" |
    Group-Object -Property Path |
    Select-Object -Property Name