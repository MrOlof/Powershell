# Load Active Directory module
Import-Module ActiveDirectory

# Define common fields
$titles = @("Software Developer", "System Administrator", "Project Manager", "Network Engineer", "Database Administrator")
$departments = @("IT", "HR", "Finance", "Marketing", "Sales")
$descriptions = @("Test User", "Temporary Account", "Development Environment", "QA Account", "Automation Test")

# Define common first and last names
$firstNames = @("John", "Jane", "Michael", "Sarah", "David", "Emily", "Chris", "Anna", "James", "Laura")
$lastNames = @("Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez")

# Generate random users
for ($i = 1; $i -le 20; $i++) {
    $firstName = Get-Random -InputObject $firstNames
    $lastName = Get-Random -InputObject $lastNames
    $username = "$firstName.$lastName$i"
    $password = ConvertTo-SecureString "P@ssw0rd!$i" -AsPlainText -Force
    $jobTitle = Get-Random -InputObject $titles
    $department = Get-Random -InputObject $departments
    $description = Get-Random -InputObject $descriptions

    # Create AD user
    New-ADUser -Name "$firstName $lastName" `
               -GivenName $firstName `
               -Surname $lastName `
               -SamAccountName $username `
               -UserPrincipalName "$username@domain.com" `
               -AccountPassword $password `
               -Enabled $true `
               -Department $department `
               -Title $jobTitle `
               -Description $description `
               -Path "OU=TestLab,DC=domain,DC=com"
    
    Write-Output "Created user: $username"
}

Write-Output "20 random AD users created successfully."
