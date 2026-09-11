cls

$path = "C:\Andrés\Scripts\9 - PowerShell and CMD\Email_Appointments"

Import-Module "$path\GlobalFunctions.ps1"

#DBA Name
$dbaName = "Andres"

#CTASK Number
$ctask = "CTASK2846948"

#Work Start Date
$date = "2021-07-25 11:00:00"

#CTASK Instructions
$Instructions = "INSTRUCTIONS"

#Email Subject
$subject = "SUJECT"

#Email Body
$body = "Hello $dbaName,
 
I hope you’re well.
 
Since you are the On Call DBA for this date on Guru, I just assigned this $ctask to you. Please see the instructions below:

$Instructions"

#------------------------------------------------------------------#

$dbaEmail = DBAEmail -dbaName $grantDBAName -path $path

#Create Grant Appointmen
AppointmentCreation -email $dbaEmail -ctask $grantCtask -date $grantDate -subject $subject -body $body

