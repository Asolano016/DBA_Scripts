cls

$path = "C:\Andrés\Scripts\9 - PowerShell and CMD\Email_Appointments"

Import-Module "$path\GlobalFunctions.ps1"

#DBA Name
$dbaName = "DBA"

#CTASK Number
$ctask = "CTASK"

#Work Start Date
$date = "DATE"

#CTASK Instructions
$Instructions = "INSTRUCTIONS"

#Email Subject
$subject = "SUJECT"

#Email Body
$body = "BODY"

#------------------------------------------------------------------#

$dbaEmail = DBAEmail -dbaName $grantDBAName -path $path

#Create Grant Appointmen
AppointmentCreation -email $dbaEmail -ctask $grantCtask -date $grantDate -subject $subject -body $body

