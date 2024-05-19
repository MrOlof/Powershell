# PowerShell Repository

Welcome to my PowerShell repository! Here you will find a collection of useful PowerShell scripts for various administrative tasks. Feel free to explore, use, and modify the scripts to suit your needs.

## Table of Contents

- [Introduction](#introduction)
- [List of Scripts](#list-of-scripts)
- [Usage Instructions](#usage-instructions)
- [Contributing](#contributing)
- [License](#license)

## Introduction

This repository contains a variety of PowerShell scripts designed to automate and simplify system administration tasks. From user management in Active Directory to generating system reports, these scripts aim to make your life easier.

## List of Scripts

Here are some of the key scripts available in this repository:

### 1. AADCopyGroupMembership.ps1
- **Description**: Copies group membership from one Azure Active Directory (AAD) user to another.
- **Path**: [`AADCopyGroupMembership.ps1`](AADCopyGroupMembership.ps1)

### 2. ADUserBulkCreateLAB.ps1
- **Description**: Creates multiple Active Directory users in bulk for lab environments with common fields populated.
- **Path**: [`ADUserBulkCreateLAB.ps1`](ADUserBulkCreateLAB.ps1)

### 3. ADUserReport.ps1
- **Description**: Generates a report of Active Directory users with specified properties.
- **Path**: [`ADUserReport.ps1`](ADUserReport.ps1)

### 4. CDNSharePoint.ps1
- **Description**: Checks the status of both private and public CDNs in SharePoint Online.
- **Path**: [`CDNSharePoint.ps1`](CDNSharePoint.ps1)

### 5. DetectionScriptGet-Package.ps1
- **Description**: Detects installed applications and checks their versions against a target version.
- **Path**: [`DetectionScriptGet-Package.ps1`](DetectionScriptGet-Package.ps1)

### 6. DisabledUserConvertSharedMailbox.ps1
- **Description**: Converts user mailboxes of disabled users to shared mailboxes in Exchange Online.
- **Path**: [`DisabledUserConvertSharedMailbox.ps1`](DisabledUserConvertSharedMailbox.ps1)

### 7. GroupMembershipReport.ps1
- **Description**: Generates a report of group memberships in Active Directory.
- **Path**: [`GroupMembershipReport.ps1`](GroupMembershipReport.ps1)

### 8. LogCleanupScript.ps1
- **Description**: Cleans up old log files from a specified directory.
- **Path**: [`LogCleanupScript.ps1`](LogCleanupScript.ps1)

### 9. SystemReport.ps1
- **Description**: Generates a detailed system health report including CPU, memory, disk usage, and network adapter status.
- **Path**: [`SystemReport.ps1`](SystemReport.ps1)

## Usage Instructions

1. **Clone the Repository**:
    ```sh
    git clone https://github.com/yourusername/your-repo-name.git
    cd your-repo-name
    ```

2. **Run a Script**:
    Open a PowerShell terminal and navigate to the directory of the script you want to run. Execute the script with the appropriate parameters, for example:
    ```powershell
    .\scripts\Backup-Database.ps1 -DatabaseName "YourDatabase" -BackupPath "C:\Backups"
    ```

## Contributing

Contributions are welcome! If you have a script that you think would be useful to others, please submit a pull request. Ensure that your script is well-documented and follows the existing code style.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Thank you for visiting my PowerShell repository. I hope you find these scripts useful!
