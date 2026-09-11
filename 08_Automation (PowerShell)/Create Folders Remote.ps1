$inventoryInstance = "usqasws0023"

$queryListBackupsPath = "SELECT HostName, BackupDir 
                         FROM [dbo].[tBackupDirInfo]
                         WHERE HostName = 'usqaswstc000341'"

$resultListBackupsPath = Invoke-Sqlcmd -Query $queryListBackupsPath -QueryTimeout 30 -ServerInstance $inventoryInstance -Database SQLInventory

#$resultListBackupsPath

ForEach ($server IN $resultListBackupsPath){
    $hostName = $server.HostName
    $path = $server.BackupDir

    $command = {New-Item -Path $args[0] -Name "_DHL_SystemBackups - master" -ItemType "directory"
                New-Item -Path $args[0] -Name "_DHL_SystemBackups - msdb" -ItemType "directory"
                New-Item -Path $args[0] -Name "_DHL_SystemBackups - model" -ItemType "directory"}
    
    Invoke-Command -ComputerName $hostName -ScriptBlock $command -ArgumentList $path
}

#$hostName = "usqasws0023"
#$path = "E:\SQLData_MSSQLSERVER\Backup"

#$command = {New-Item -Path $args[0] -Name "_DHL_SystemBackups - master" -ItemType "directory"
#            New-Item -Path $args[0] -Name "_DHL_SystemBackups - msdb" -ItemType "directory"
#            New-Item -Path $args[0] -Name "_DHL_SystemBackups - model" -ItemType "directory"}
#
#Invoke-Command -ComputerName $hostName -ScriptBlock $command -ArgumentList $path