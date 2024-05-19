# Import the Exchange Online PowerShell module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
$UserCredential = Get-Credential
Connect-ExchangeOnline -UserPrincipalName $UserCredential.UserName -Password $UserCredential.GetNetworkCredential().Password

# Get disabled user accounts with associated mailboxes
$disabledUsers = Get-ADUser -Filter {Enabled -eq $false} -Property DisplayName, UserPrincipalName, Mail | Where-Object { $_.Mail -ne $null }

foreach ($user in $disabledUsers) {
    # Check if the mailbox exists
    $mailbox = Get-Mailbox -Identity $user.UserPrincipalName -ErrorAction SilentlyContinue
    if ($mailbox) {
        # Check if the mailbox is already a shared mailbox
        $mailboxType = $mailbox.RecipientTypeDetails
        if ($mailboxType -ne "SharedMailbox") {
            # Convert the user mailbox to a shared mailbox
            Set-Mailbox -Identity $user.UserPrincipalName -Type Shared
            Write-Output "Converted mailbox of disabled user $($user.DisplayName) ($($user.UserPrincipalName)) to a shared mailbox."
        } else {
            Write-Output "Mailbox of disabled user $($user.DisplayName) ($($user.UserPrincipalName)) is already a shared mailbox."
        }
    } else {
        Write-Output "No mailbox found for disabled user $($user.DisplayName) ($($user.UserPrincipalName))."
    }
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false

Write-Output "Completed converting disabled user mailboxes to shared mailboxes."
