# Load the SharePoint Online Management Shell module
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

# Function to check and display CDN status
function Get-CDNStatus {
    param (
        [string]$cdnType
    )

    try {
        $cdnStatus = Get-SPOTenantCdnOrigins -CdnType $cdnType
        Write-Output "$cdnType CDN Origins:"
        $cdnStatus | ForEach-Object {
            Write-Output "Origin: $($_.OriginUrl)"
            Write-Output "  IsEnabled: $($_.IsEnabled)"
        }
    } catch {
        Write-Output "Error getting $cdnType CDN status: $_"
    }
}

# Prompt for SharePoint Online credentials
$cred = Get-Credential

# Connect to SharePoint Online
$tenantAdminUrl = Read-Host "Enter your SharePoint Online Tenant Admin URL (e.g., https://yourtenant-admin.sharepoint.com)"
Connect-SPOService -Url $tenantAdminUrl -Credential $cred

# Check and display the status of both private and public CDNs
Write-Output "Checking SharePoint Online CDN settings..."

Write-Output "Private CDN:"
Get-CDNStatus -cdnType "Private"

Write-Output "`nPublic CDN:"
Get-CDNStatus -cdnType "Public"

# Disconnect from SharePoint Online
Disconnect-SPOService

Write-Output "CDN settings check completed."
