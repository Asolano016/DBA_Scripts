cls
$recipients = @("asolano016@outlook.com","andres.solanoalpizar@dhl.com")
$gaprv = "GAPRVTEST"
$subject = "RFC1616320/ $gaprv Backup MSSQL system databases with new SQL Agent Job approval" 
$body    = "Hello Team,

I hope you’re well.

I´m looking for your approval to start working on RFC1616320, this change won't cause any impact on your systems and no outage is required. 

This is a really simple script that wil create a new SQL Agent Job that will backp the system master database locally.

MSSQL Team is implementing this job in order to improve the recovery of the master database, so in case of failure or corruption, we can recover the master database in a more faster way. Currently NetBackup won't be able to recover the master database if it fails, since this system won't be able to work because SQL Server will be down if the master databases is failing.

Can you please check it and approve " + $gaprv + "?

Feel free to let me now if you have questions or doubts.

Andrés Solano Alpízar
MS SQL DBA
Production Services (PdS)
Phone: (+506) 2508-4101"


$outlook = New-Object -ComObject Outlook.Application
$mail = $Outlook.CreateItem(0)
$mail.Subject = $subject 
$mail.Body = $body
$mail.Recipients.Add($recipients)
$mail.Send()  