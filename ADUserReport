# Finding out who's who in your AD forest!
$users = Get-ADUser -Filter * -Property DisplayName, EmailAddress, LastLogonDate
$users | Select-Object DisplayName, EmailAddress, LastLogonDate | Export-Csv -Path "C:\Reports\ADUsers.csv" -NoTypeInformation
Write-Output "AD user report generated and saved to C:\Reports\ADUsers.csv"
