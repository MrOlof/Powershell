# Display a cool ASCII art title
Write-Host "
    ____            _       _   
   / ___| ___ _ __ | |_ ___| |_ 
  | |  _ / _ \ '_ \| __/ __| __|
  | |_| |  __/ | | | |_\__ \ |_ 
   \____|\___|_| |_|\__|___/\__|
                                 
"

# CPU Usage
$cpuUsage = (Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

# Memory Usage
$memory = Get-WmiObject -Class Win32_OperatingSystem
$totalMemory = [math]::round($memory.TotalVisibleMemorySize / 1MB, 2)
$freeMemory = [math]::round($memory.FreePhysicalMemory / 1MB, 2)
$usedMemory = $totalMemory - $freeMemory

# Disk Usage
$diskUsage = Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{Name="Used(GB)";Expression={[math]::round($_.Used/1GB,2)}}, @{Name="Free(GB)";Expression={[math]::round($_.Free/1GB,2)}}

# Network Adapter Info
$networkAdapters = Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress

# Battery Report
$batteryReportPath = "C:\battery_report.html"
powercfg /batteryreport /output $batteryReportPath
Write-Output "Battery report generated and saved to $batteryReportPath"

# Creating a readable system health report
$report = @"
System Health Report
--------------------
CPU Usage: [math]::round($cpuUsage, 2) %
Memory Usage: Total = $totalMemory GB, Used = $usedMemory GB, Free = $freeMemory GB
Disk Usage:
@($diskUsage | Format-Table -AutoSize | Out-String)
Network Adapters:
@($networkAdapters | Format-Table -AutoSize | Out-String)
Battery Report: See $batteryReportPath for detailed battery information
"@

# Output the report
Write-Host $report

# Save the report to a file
$report | Out-File -FilePath "C:\Reports\SystemHealthReport.txt"
Write-Output "System health report generated and saved to C:\Reports\SystemHealthReport.txt"
