cls

$path = "C:\Andrés\Scripts\9 - PowerShell and CMD\Email_Appointments"

Import-Module "$path\GlobalFunctions.ps1"

#Approval Type, Option: Automatic or Manual
$approvalType = "Automatic"

#Grant Informaiton
$grantDBAName = "Andres"
$grantCtask = "CTASKTEST"
$grantDate = "2021-07-25 10:00"


#Grant Informaiton
$revokeDBAName = "Andres"
$revokeCtask = "CTASKTEST_Revoke"
$revokeDate = "2021-07-25 15:00"

$grantBDAEmail = DBAEmail -dbaName $grantDBAName -path $path
$revokeBDAEmail = DBAEmail -dbaName $revokeDBAName -path $path

#------------------------------------------------------------------#

If("Automatic" -match $approvalType){
    #Create Grant Appointment for Automation Approval 
    GrantAutomaticSysadmin -email $grantBDAEmail -ctask $grantCtask -date $grantDate

    #Create Revoke Appointment for Automation Approval 
    RevokeAutomaticSysadmin -email $revokeBDAEmail -ctask $revokeCtask -date $revokeDate   
}
ELSEIf("Manual" -match $approvalType ){
    #Create Grant Appointment for Manual Approval 
    GrantNoAutomaticSysadmin -email $grantBDAEmail -ctask $grantCtask -date $grantDate

    #Create Revoke Appointment for Manual Approval 
    RevokeNoAutomaticSysadmin -email $revokeBDAEmail -ctask $revokeCtask -date $revokeDate 
}
ELSE {
    Write-Error "Invalid Approval Type. Please try Automatic or Manual." -ErrorAction Stop   
}
