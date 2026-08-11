<#
.SYNOPSIS
    Apex Health Systems - Daily SysAdmin Routine Check (Task 3 PoC, Windows Server)

.DESCRIPTION
    1. Checks disk usage on all local drives, flags any over $DiskThreshold
    2. Pulls failed logon events (Event ID 4625) from the Security event log
    3. Checks the status of critical services listed in $Services
    4. Writes a timestamped report to $LogDir and prints a summary to the console

.NOTES
    Suggested Task Scheduler trigger: Daily at 7:00 AM
    Run as: powershell.exe -ExecutionPolicy Bypass -File Daily-HealthCheck.ps1
    Must be run with an account that can read the Security event log (typically admin).
#>

# ---------- Configuration ----------
$DiskThreshold = 80                                   # percent used before flagging
$Services = @("Spooler", "W32Time", "EventLog")       # edit to match your critical services
$LogDir = "C:\ApexHealthChecks"
$DateStamp = Get-Date -Format "yyyy-MM-dd"
$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $LogDir "healthcheck_$DateStamp.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

function Write-Log {
    param([string]$Message)
    Write-Output $Message
    Add-Content -Path $LogFile -Value $Message
}

Write-Log "========================================"
Write-Log "Apex Health Systems - Daily Health Check"
Write-Log "Run time: $TimeStamp"
Write-Log "========================================"

# ---------- 1. Disk Usage Check ----------
Write-Log ""
Write-Log "--- Disk Usage ---"
$Flagged = 0
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    if ($_.Size -gt 0) {
        $UsedPct = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 1)
        if ($UsedPct -ge $DiskThreshold) {
            Write-Log "  [WARNING] Drive $($_.DeviceID) is at $UsedPct% used (threshold: $DiskThreshold%)"
            $Flagged++
        }
    }
}
if ($Flagged -eq 0) {
    Write-Log "  All drives below $DiskThreshold% usage."
} else {
    Write-Log "  $Flagged drive(s) flagged above threshold."
}

# ---------- 2. Failed Logon Attempts (Event ID 4625) ----------
Write-Log ""
Write-Log "--- Failed Logon Attempts (last 24h) ---"
try {
    $Since = (Get-Date).AddHours(-24)
    $FailedLogons = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security'
        Id        = 4625
        StartTime = $Since
    } -ErrorAction Stop

    Write-Log "  Total failed logon events: $($FailedLogons.Count)"
    if ($FailedLogons.Count -gt 0) {
        Write-Log "  Top offending source IPs:"
        $FailedLogons |
            ForEach-Object { ([xml]$_.ToXml()).Event.EventData.Data |
                Where-Object { $_.Name -eq 'IpAddress' } | Select-Object -ExpandProperty '#text' } |
            Group-Object |
            Sort-Object Count -Descending |
            Select-Object -First 5 |
            ForEach-Object { Write-Log "    $($_.Name) - $($_.Count) attempt(s)" }
    }
} catch {
    Write-Log "  [INFO] No failed logon events found or Security log not accessible: $($_.Exception.Message)"
}

# ---------- 3. Critical Service Status ----------
Write-Log ""
Write-Log "--- Critical Service Status ---"
$ServiceIssues = 0
foreach ($svc in $Services) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Log "  [INFO] Service '$svc' not found on this host"
    } elseif ($service.Status -eq 'Running') {
        Write-Log "  [OK] $svc is running"
    } else {
        Write-Log "  [ALERT] $svc is NOT running (status: $($service.Status))"
        $ServiceIssues++
    }
}

# ---------- Summary ----------
Write-Log ""
Write-Log "--- Summary ---"
Write-Log "  Disk warnings: $Flagged"
Write-Log "  Service issues: $ServiceIssues"
Write-Log "  Full report saved to: $LogFile"
Write-Log "========================================"
