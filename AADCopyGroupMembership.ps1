# Import the AzureAD module
Import-Module AzureAD

# Prompt for Azure AD credentials
$credentials = Get-Credential

# Connect to Azure AD
Connect-AzureAD -Credential $credentials

# Prompt for source and target users
$sourceUserUPN = Read-Host "Enter the UPN (User Principal Name) of the source user (from whom to copy group memberships)"
$targetUserUPN = Read-Host "Enter the UPN (User Principal Name) of the target user (to whom to copy group memberships)"

# Retrieve the source and target user objects
$sourceUser = Get-AzureADUser -ObjectId $sourceUserUPN
$targetUser = Get-AzureADUser -ObjectId $targetUserUPN

# Check if both users exist
if (-not $sourceUser) {
    Write-Error "Source user '$sourceUserUPN' not found."
    exit
}
if (-not $targetUser) {
    Write-Error "Target user '$targetUserUPN' not found."
    exit
}

# Get the group memberships of the source user
$sourceUserGroups = Get-AzureADUserMembership -ObjectId $sourceUser.ObjectId

# Copy group memberships to the target user
foreach ($group in $sourceUserGroups) {
    # Check if the target user is already a member of the group
    $isMember = Get-AzureADGroupMember -ObjectId $group.ObjectId | Where-Object {$_.ObjectId -eq $targetUser.ObjectId}
    if (-not $isMember) {
        # Add the target user to the group
        Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $targetUser.ObjectId
        Write-Output "Added $($targetUserUPN) to group $($group.DisplayName)"
    } else {
        Write-Output "$($targetUserUPN) is already a member of group $($group.DisplayName)"
    }
}

Write-Output "Group memberships have been copied from $($sourceUserUPN) to $($targetUserUPN)."

# Disconnect from Azure AD
Disconnect-AzureAD
