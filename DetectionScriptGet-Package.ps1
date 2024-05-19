# Target app and version to look for
$appName = "Google Chrome"
$targetVersion = [Version]"124.0.6367.202"

try {
    # Retrieve the version of the app using Get-Package
    $installedVersionString = (Get-Package -Name "$appName").Version
    $installedVersion = [Version]$installedVersionString
    Write-Host "Installed $appName Version: $installedVersion"

    # Compare the installed version with the target version
    if ($installedVersion -lt $targetVersion) {
        Write-Host "$appName version is below the target."
        exit 1  # Exit code 1 signals that the app is installed and version is less than specified
    } else {
        Write-Host "$appName version meets or exceeds the target."
        exit 0  # Exit code 0 signals that the app is installed and version is same or greater
    }
} catch {
    Write-Host "$appName may not be installed."
    exit 0  # Exit code 0 signals that the app is not installed
}
