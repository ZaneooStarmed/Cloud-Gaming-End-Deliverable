# Check if Dolphin is running and return its metrics as JSON

$dolphinProcess = Get-Process -Name "Dolphin" -ErrorAction SilentlyContinue

if ($dolphinProcess) {
    $metrics = @{
        dolphin_running  = $true
        process_id       = $dolphinProcess.Id
        cpu_usage        = [math]::Round($dolphinProcess.CPU, 2)
        memory_mb        = [math]::Round($dolphinProcess.WorkingSet64 / 1MB, 2)
        start_time       = $dolphinProcess.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
        uptime_seconds   = [math]::Round((New-TimeSpan -Start $dolphinProcess.StartTime -End (Get-Date)).TotalSeconds, 0)
    }
} else {
    $metrics = @{
        dolphin_running  = $false
        process_id       = $null
        cpu_usage        = $null
        memory_mb        = $null
        start_time       = $null
        uptime_seconds   = $null
    }
}

# Output as JSON so server.js can read it
$metrics | ConvertTo-Json