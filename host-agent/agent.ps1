$commandFile  = "C:\Users\Zane\Desktop\CloudGaming\logs\command.txt"
$statusFile   = "C:\Users\Zane\Desktop\CloudGaming\logs\status.json"
$logFile      = "C:\Users\Zane\Desktop\CloudGaming\logs\agent.log"
$dolphinPath  = "C:\Program Files\Dolphin-x64\Dolphin.exe"
$counterFile  = "C:\Users\Zane\Desktop\CloudGaming\logs\session_counter.json"
$networkAdapter = "Ethernet 4"

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $message"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Get-SessionCount {
    try {
        if (Test-Path $counterFile) {
            $data = Get-Content $counterFile -Raw | ConvertFrom-Json
            return [int]$data.total_sessions
        }
    } catch {}
    return 0
}

function Increment-SessionCount {
    $current = Get-SessionCount
    $current++
    $obj = @{ total_sessions = $current }
    $obj | ConvertTo-Json | Set-Content -Path $counterFile
    Write-Log "Session counter incremented to: $current"
    return $current
}

function Get-SunshineProcess {
    $names = @("sunshine", "Sunshine", "sunshine-service", "sunshinesvc")
    foreach ($name in $names) {
        $proc = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($proc) {
            # Always return single process
            if ($proc -is [array]) { return $proc[0] }
            return $proc
        }
    }
    return $null
}

function Get-DolphinProcess {
    $proc = Get-Process -Name "Dolphin" -ErrorAction SilentlyContinue
    if ($proc -is [array]) { return $proc[0] }
    return $proc
}

function SafeRound {
    param($value, $digits)
    try {
        $v = [double]$value
        return [math]::Round($v, $digits)
    } catch {
        return 0
    }
}

function SafeDivide {
    param($value, $divisor)
    try {
        $v = [double]$value
        $d = [double]$divisor
        if ($d -eq 0) { return 0 }
        return $v / $d
    } catch {
        return 0
    }
}

$script:prevBytesReceived = [double]0
$script:prevBytesSent     = [double]0
$script:prevTimestamp     = Get-Date

function Get-NetworkStats {
    try {
        $adapter = Get-NetAdapterStatistics -Name $networkAdapter -ErrorAction SilentlyContinue
        if (-not $adapter) {
            $adapter = Get-NetAdapterStatistics -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        if ($adapter) {
            $now     = Get-Date
            $elapsed = (New-TimeSpan -Start $script:prevTimestamp -End $now).TotalSeconds

            $rxBytes = [double]$adapter.ReceivedBytes
            $txBytes = [double]$adapter.SentBytes

            if ($elapsed -gt 0 -and $script:prevBytesReceived -gt 0) {
                $downloadBps  = ($rxBytes - $script:prevBytesReceived) / $elapsed
                $uploadBps    = ($txBytes - $script:prevBytesSent) / $elapsed
                $downloadMbps = SafeRound (($downloadBps * 8) / 1048576) 3
                $uploadMbps   = SafeRound (($uploadBps * 8) / 1048576) 3
                if ($downloadMbps -lt 0) { $downloadMbps = 0 }
                if ($uploadMbps -lt 0)   { $uploadMbps = 0 }
            } else {
                $downloadMbps = 0
                $uploadMbps   = 0
            }

            $script:prevBytesReceived = $rxBytes
            $script:prevBytesSent     = $txBytes
            $script:prevTimestamp     = $now

            $clumsyRunning = $null -ne (Get-Process -Name "clumsy" -ErrorAction SilentlyContinue)

            return @{
                network_download_mbps     = $downloadMbps
                network_upload_mbps       = $uploadMbps
                network_adapter           = $networkAdapter
                network_total_received_mb = SafeRound (SafeDivide $rxBytes 1048576) 2
                network_total_sent_mb     = SafeRound (SafeDivide $txBytes 1048576) 2
                clumsy_running            = $clumsyRunning
            }
        }
    } catch {
        Write-Log "Network stats error: $_"
    }

    return @{
        network_download_mbps     = 0
        network_upload_mbps       = 0
        network_adapter           = $networkAdapter
        network_total_received_mb = 0
        network_total_sent_mb     = 0
        clumsy_running            = $false
    }
}

function Update-Status {
    $dolphin       = Get-DolphinProcess
    $sunshine      = Get-SunshineProcess
    $totalSessions = Get-SessionCount
    $network       = Get-NetworkStats

    if ($dolphin) {
        try {
            $uptime = SafeRound (New-TimeSpan -Start $dolphin.StartTime -End (Get-Date)).TotalSeconds 0
        } catch { $uptime = 0 }
        $dRun = $true
        $dPid = [int]$dolphin.Id
        $dCpu = SafeRound ([double]$dolphin.CPU) 2
        $dMem = SafeRound (SafeDivide ([double]$dolphin.WorkingSet64) 1048576) 2
    } else {
        $uptime = 0
        $dRun   = $false
        $dPid   = $null
        $dCpu   = 0
        $dMem   = 0
    }

    if ($sunshine) {
        try {
            $sUptime = SafeRound (New-TimeSpan -Start $sunshine.StartTime -End (Get-Date)).TotalSeconds 0
        } catch { $sUptime = 0 }
        $sRun  = $true
        $sPid  = [int]$sunshine.Id
        $sCpu  = SafeRound ([double]$sunshine.CPU) 2
        $sMem  = SafeRound (SafeDivide ([double]$sunshine.WorkingSet64) 1048576) 2
        $sName = $sunshine.Name
    } else {
        $sUptime = 0
        $sRun    = $false
        $sPid    = $null
        $sCpu    = 0
        $sMem    = 0
        $sName   = "not found"
    }

    $status = @{
        timestamp                 = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        total_sessions            = $totalSessions
        dolphin_running           = $dRun
        process_id                = $dPid
        cpu_usage                 = $dCpu
        memory_mb                 = $dMem
        uptime_seconds            = $uptime
        sunshine_running          = $sRun
        sunshine_pid              = $sPid
        sunshine_cpu              = $sCpu
        sunshine_memory           = $sMem
        sunshine_uptime           = $sUptime
        sunshine_name             = $sName
        network_download_mbps     = $network.network_download_mbps
        network_upload_mbps       = $network.network_upload_mbps
        network_adapter           = $network.network_adapter
        network_total_received_mb = $network.network_total_received_mb
        network_total_sent_mb     = $network.network_total_sent_mb
        clumsy_running            = $network.clumsy_running
    }

    $status | ConvertTo-Json | Set-Content -Path $statusFile
}

Write-Log "Host Agent started with network monitoring"
Write-Log "Network adapter: $networkAdapter"
Write-Log "Dolphin path: $dolphinPath"
Write-Log "Total sessions so far: $(Get-SessionCount)"

$testSunshine = Get-SunshineProcess
if ($testSunshine) {
    Write-Log "Sunshine detected - process name: $($testSunshine.Name)"
} else {
    Write-Log "WARNING: Sunshine not detected yet - will keep checking"
}

Update-Status
$lastDolphinState = $false

while ($true) {
    if (Test-Path $commandFile) {
        $command = (Get-Content $commandFile -Raw).Trim()
        Remove-Item $commandFile -Force
        Write-Log "Received command: $command"

        if ($command -eq "START") {
            $existing = Get-DolphinProcess
            if ($existing) {
                Write-Log "Dolphin already running"
            } elseif (Test-Path $dolphinPath) {
                Start-Process -FilePath $dolphinPath
                Write-Log "Dolphin launched by agent"
                Start-Sleep -Seconds 3
            } else {
                Write-Log "ERROR: Dolphin path not found: $dolphinPath"
            }
        } elseif ($command -eq "STOP") {
            Stop-Process -Name "Dolphin" -Force -ErrorAction SilentlyContinue
            Write-Log "Dolphin stopped by agent"
        } elseif ($command -eq "STATUS") {
            Write-Log "Manual status check requested"
        }
    }

    $currentDolphinState = $null -ne (Get-DolphinProcess)

    if ($currentDolphinState -and -not $lastDolphinState) {
        $newCount = Increment-SessionCount
        Write-Log "NEW SESSION DETECTED - Total sessions: $newCount"
    }

    if (-not $currentDolphinState -and $lastDolphinState) {
        Write-Log "Dolphin session ended"
    }

    $lastDolphinState = $currentDolphinState
    Update-Status
    Start-Sleep -Seconds 2
}
