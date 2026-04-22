# Stop Dolphin process
Stop-Process -Name "Dolphin" -Force -ErrorAction SilentlyContinue

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path "C:\CloudGaming\logs\sessions.log" -Value "$timestamp,STOP"

Write-Host "Gaming session terminated"