#Region RunTrLogBackup - start transaction log backup
Function RunTrLogBackup {
    param (
        [parameter(Mandatory=$true,Position=0)] $InstDetail,
        [parameter(Mandatory=$true,Position=1)] $LogBackupScript
    )

    $HostName = $InstDetail.HostName
    $Instance = $InstDetail.Instance
    $DbBackex = "C:\PROGRA~1\VERITAS\NetBackup\bin\dbbackex.exe"
    $NbServer = GetBchDetail -Instance $Instance -HostName $HostName -DetailName "NBSERVER" -LogBack $LogBackupScript
    $Lbs = $LogBackupScript
    $LocalLogBackupScript = "C:\" + $Lbs.Substring($Lbs.IndexOf("c$")+2,($Lbs.Length - $Lbs.IndexOf("c$")-2))
    $Arguments = '-s "' + $NbServer + '" -f "' + $LocalLogBackupScript + '" -np'

    # Create a persistent remote session
    $Session = New-PSSession -ComputerName $HostName

    # Run the backup remotely and return PID immediately
    $ProcessID = Invoke-Command -Session $Session -ScriptBlock {
        param($DbBackex, $Arguments)

        # Start the process asynchronously (do not wait)
        $Process = Start-Process -FilePath $DbBackex -ArgumentList $Arguments -WindowStyle Hidden -PassThru

        # Return only the PID
        return $Process.Id
    } -ArgumentList $DbBackex, $Arguments

    # Optionally remove the session if you don't need it anymore
    #Remove-PSSession $Session

    # Return both the PID and the session object
    return $ProcessID
}
#EndRegion