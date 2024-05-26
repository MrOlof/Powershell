# Import the CSV file
$devices = Import-Csv -Path "path\90days.csv"

# Define the target OU for disabled devices
$targetOU = "path"

# Loop through each device and disable it, then move it to the target OU
foreach ($device in $devices) {
    # Get the device name
    $deviceName = $device.DeviceName  # Use the correct column header from your CSV

    if ($deviceName) {
        try {
            # Get the distinguished name of the computer object with a broader search scope
            $computer = Get-ADComputer -Filter { Name -eq $deviceName } -SearchBase "Forest" -SearchScope Subtree
            
            if ($computer) {
                $distinguishedName = $computer.DistinguishedName
                
                # Disable the computer account
                Disable-ADAccount -Identity $distinguishedName
                Write-Output "Disabled device: $deviceName"
                
                # Move the computer object to the target OU
                Move-ADObject -Identity $distinguishedName -TargetPath $targetOU
                Write-Output "Moved device: $deviceName to $targetOU"
            } else {
                Write-Output "Device not found: $deviceName"
            }
        } catch {
            Write-Output "Failed to process device: $deviceName. Error: $_"
        }
    } else {
        Write-Output "No device name found for entry: $device"
    }
}
