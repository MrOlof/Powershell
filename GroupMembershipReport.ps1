# Load Active Directory module
Import-Module ActiveDirectory

# Define the group name
$groupName = "YourGroupName"

# Get group members
$groupMembers = Get-ADGroupMember -Identity $groupName -Recursive | Get-ADUser -Property DisplayName, EmailAddress, Department, Title

# Create report
$reportPath = "C:\Reports\GroupMembershipReport.csv"
$groupMembers | Select-Object DisplayName, EmailAddress, Department, Title | Export-Csv -Path $reportPath -NoTypeInformation

Write-Output "Group membership report generated and saved to $reportPath"
