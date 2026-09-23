Get-ADGroup -server phx-dc AccountName -properties * 

get-aduser -server phx-dc AccountName -properties Name, Enabled, modifyTimeStamp, LockedOut, whenCreated, whenChanged
get-aduser -server kul-dc AccountName -properties Name, Enabled, modifyTimeStamp, LockedOut, whenCreated, whenChanged

get-aduser -server prg-dc AccountName -properties *

get-adgroup -server prg-dc "AccountName" -properties Name, Enabled, GroupCategory, GroupScope, modifyTimeStamp, whenCreated, whenChanged
get-adgroup -server prg-dc "AccountName" -propertie *


#$user = "AccountName"
#$newPass = "PASSWORD"

#Set-ADAccountPassword -Identity "AccountName" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "PASSWORD" -Force)

#Set-ADAccountPassword -Identity "AccountName" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "PASSWORD" -Force)

#Unlock-ADAccount -Identity "AccountName"
#Unlock-ADAccount -Identity "AccountName"


#Set-ADAccountPassword -Identity AccountName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "PASSWORD" -Force)

#Set-ADAccountPassword -Identity AccountName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "PASSWORD" -Force)

cls

#New-ADGroup -Server phx-dc -Name AccountName -GroupCategory Security -GroupScope Universal -Path "OU=DelegationGroups,OU=MSSQL,OU=Applications,DC=phx-dc,DC=dhl,DC=com" -ManagedBy "GDLPHXDC-US.GTWTOOLS.SUPPORT" -Description INC43862058 

#gmsa
Get-ADServiceAccount -Identity AccountName