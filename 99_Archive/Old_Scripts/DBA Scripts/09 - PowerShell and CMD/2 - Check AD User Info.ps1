Get-ADGroup -server phx-dc UDLDHL-USQASWSPC000128_TAR -properties * 

get-aduser -server phx-dc srv_phxdc-comprep -properties Name, Enabled, modifyTimeStamp, LockedOut, whenCreated, whenChanged
get-aduser -server kul-dc srv_mykul-sql1519 -properties Name, Enabled, modifyTimeStamp, LockedOut, whenCreated, whenChanged

get-aduser -server prg-dc EXP_NL_REPORT -properties *

get-adgroup -server prg-dc "EXPDAC-Robots-Prod" -properties Name, Enabled, GroupCategory, GroupScope, modifyTimeStamp, whenCreated, whenChanged
get-adgroup -server prg-dc "EXPDAC-Robots-Prod" -propertie *


#$user = "srv_mykul_sqlv1198"
#$newPass = "A1i01*.lxW~*%4a~o^Qr"

#Set-ADAccountPassword -Identity "KUL-DC\srv_mykul_sqlv1198" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "Ks_*by34?by23k$&n4ub5" -Force)

#Set-ADAccountPassword -Identity "srv_mykul_sqlva1198" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "Ks_*by34?jy23k$&nYeb5" -Force)

#Unlock-ADAccount -Identity "srv_mykul_sqlva1198"
#Unlock-ADAccount -Identity "srv_mykul_sqlva1196"


#Set-ADAccountPassword -Identity KUL-DC\srv_mykul-sqlv1236 -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "W&hxwN:e[W+onJ`:8t?m?w;zVBvZ9#cTR" -Force)

#Set-ADAccountPassword -Identity KUL-DC\srv_mykul-sqlva1236 -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "NJrn:yN~AnCc8=Vca[73BH9:52JO,x;aB" -Force)

cls

#New-ADGroup -Server phx-dc -Name UDLDHL-USCVGWS40010-AM_NetOps_Safety_READ -GroupCategory Security -GroupScope Universal -Path "OU=DelegationGroups,OU=MSSQL,OU=Applications,DC=phx-dc,DC=dhl,DC=com" -ManagedBy "GDLPHXDC-US.GTWTOOLS.SUPPORT" -Description INC43862058 

#gmsa
Get-ADServiceAccount -Identity GS_PRG_MCTT