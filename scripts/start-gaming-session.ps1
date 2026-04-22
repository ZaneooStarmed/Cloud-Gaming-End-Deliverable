param([string]$Game = "default")

Write-Host "Starting gaming session for: $Game"

# Launch Dolphin Emulator on host
$dolphinPath = "C:\Program Files\Dolphin\Dolphin.exe"

if (Tcleest-Path $dolphinPath) {
    Start-Process -FilePath $dolphinPath -WindowStyle Normal
    Write-Host "Dolphin launched successfully"
    
    # Log session start time for latency benchmarking
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "C:\CloudGaming\logs\sessions.log" -Value "$timestamp,START,$Game"
} else {
    Write-Host "ERROR: Dolphin not found at $dolphinPath"
    exit 1
}