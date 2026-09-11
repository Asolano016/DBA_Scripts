Function DBAEmail{

    param (
        $dbaName,
        $path
    )

    $teamList = Import-Csv -Path "$path\MSSQLTeam.csv"

    $dbaEmail = ""

    ForEach($team in $teamList){

        If($team.Name -match $dbaName){
            $dbaEmail = $team.Email
        }
    }

    If($dbaEmail -eq ""){
        cls
        #Write-Host "Invalid DBA name. Please try again." -fore red
        Write-Error "Invalid DBA name. Please try again." -ErrorAction Stop
    }

    $dbaEmail
 
}

Function CustomAppointment{

    param (
        $email,
        $ctask,
        $date,
        $subject,
        $body
    )

    $ol = New-Object -ComObject Outlook.Application
    $meeting = $ol.CreateItem("olAppointmentItem")
    $meeting.Subject = $ctask + " - " + $subject
    $meeting.Body = $body
    $meeting.Location = "Virtual"
    $meeting.ReminderSet = $true
    $meeting.Importance = 1
    $meeting.MeetingStatus = [Microsoft.Office.Interop.Outlook.OlMeetingStatus]::olMeeting
    $meeting.Recipients.Add($email)
    $meeting.ReminderMinutesBeforeStart = 15
    $meeting.Start = Get-Date $date
    $meeting.Duration = 30
    $meeting.Send()  
}

Function GrantAutomaticSysadmin{

    param (
        $email,
        $ctask,
        $date
    )

    $ol = New-Object -ComObject Outlook.Application
    $meeting = $ol.CreateItem("olAppointmentItem")
    $meeting.Subject = $ctask + " - Grant temporary Sysadmin access"
    $meeting.Body = "Hello,

Process approved with automation, please use the script to grant the access."
    $meeting.Location = "Virtual"
    $meeting.ReminderSet = $true
    $meeting.Importance = 1
    $meeting.MeetingStatus = [Microsoft.Office.Interop.Outlook.OlMeetingStatus]::olMeeting
    $meeting.Recipients.Add($email)
    $meeting.ReminderMinutesBeforeStart = 15
    $meeting.Start = Get-Date $date
    $meeting.Duration = 30
    $meeting.Send()  
}

Function RevokeAutomaticSysadmin{

    param (
        $email,
        $ctask,
        $date
    )

    $ol = New-Object -ComObject Outlook.Application
    $meeting = $ol.CreateItem("olAppointmentItem")
    $meeting.Subject = $ctask + " - Revoke temporary Sysadmin access"
    $meeting.Body = "Hello,

Process approved with automation, please use the script to revoke the access."
    $meeting.Location = "Virtual"
    $meeting.ReminderSet = $true
    $meeting.Importance = 1
    $meeting.MeetingStatus = [Microsoft.Office.Interop.Outlook.OlMeetingStatus]::olMeeting
    $meeting.Recipients.Add($email)
    $meeting.ReminderMinutesBeforeStart = 15
    $meeting.Start = Get-Date $date
    $meeting.Duration = 30
    $meeting.Send()  
}

Function GrantNoAutomaticSysadmin{

    param (
        $email,
        $ctask,
        $date
    )

    $ol = New-Object -ComObject Outlook.Application
    $meeting = $ol.CreateItem("olAppointmentItem")
    $meeting.Subject = $ctask + " - Grant temporary Sysadmin access"
    $meeting.Body = "Hello,

Process approved without automation, please grant the access manually."
    $meeting.Location = "Virtual"
    $meeting.ReminderSet = $true
    $meeting.Importance = 1
    $meeting.MeetingStatus = [Microsoft.Office.Interop.Outlook.OlMeetingStatus]::olMeeting
    $meeting.Recipients.Add($email)
    $meeting.ReminderMinutesBeforeStart = 15
    $meeting.Start = Get-Date $date
    $meeting.Duration = 30
    $meeting.Send()  
}

Function RevokeNoAutomaticSysadmin{

    param (
        $email,
        $ctask,
        $date
    )

    $ol = New-Object -ComObject Outlook.Application
    $meeting = $ol.CreateItem("olAppointmentItem")
    $meeting.Subject = $ctask + " - Grant temporary Sysadmin access"
    $meeting.Body = "Hello,

Process approved without automation, please revoke the access manually."
    $meeting.Location = "Virtual"
    $meeting.ReminderSet = $true
    $meeting.Importance = 1
    $meeting.MeetingStatus = [Microsoft.Office.Interop.Outlook.OlMeetingStatus]::olMeeting
    $meeting.Recipients.Add($email)
    $meeting.ReminderMinutesBeforeStart = 15
    $meeting.Start = Get-Date $date
    $meeting.Duration = 30
    $meeting.Send()  
}