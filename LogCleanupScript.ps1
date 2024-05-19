# Keeping your logs neat and tidy like a librarian!
$logPath = "C:\Logs"
$days = 30
$files = Get-ChildItem -Path $logPath -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$days) }
foreach ($file in $files) {
    Remove-Item $file.FullName -Force
    Write-Output "Deleted $($file.FullName)"
}
