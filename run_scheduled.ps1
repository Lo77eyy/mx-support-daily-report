# ============================================================
#  MX Support Daily Report - Scheduled Task Script (PowerShell)
#  Runs pipeline + sends DingTalk notification to Amiee
# ============================================================

$ErrorActionPreference = 'Continue'

# Configuration
$Python = 'C:\Users\GL\AppData\Local\Programs\Python\Python314\python.exe'
$ScriptDir = 'C:\Users\GL\.qoderworkcn\workspace\mr2y9wr285i946sj\repo\mx-support-daily-report'
$Dws = Join-Path $ScriptDir 'bin\dws.exe'
$LogDir = Join-Path $ScriptDir 'logs'
$AmieeUserId = '1778031662885144'

# Create logs directory
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# Log file
$LogDate = Get-Date -Format 'yyyy-MM-dd'
$LogFile = Join-Path $LogDir "scheduled_$LogDate.log"

function Write-Log($msg) {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "[$ts] $msg" | Tee-Object -FilePath $LogFile -Append
}

Write-Log "============================================================"
Write-Log "Scheduled task started"
Write-Log "============================================================"

# Step 0: Pre-check DingTalk auth status
Write-Log "Checking DingTalk auth status..."
$AuthOutput = & $Dws auth status --format json 2>&1
$AuthExit = $LASTEXITCODE
$AuthOutput | ForEach-Object { Write-Log $_ }

$AuthValid = $false
try {
    $AuthText = $AuthOutput | Out-String
    if ($AuthText -match '"authenticated"\s*:\s*true') {
        $AuthValid = $true
        if ($AuthText -match '"user_name"\s*:\s*"([^"]+)"') {
            Write-Log "DingTalk auth OK (user: $($Matches[1]))"
        } else {
            Write-Log "DingTalk auth OK"
        }
    }
} catch {
    Write-Log "Warning: Could not check auth status - $_"
}

if (-not $AuthValid) {
    Write-Log "WARNING: DingTalk not authenticated. Notification will fail at the end."
    Write-Log "Run 'dws auth login' manually to re-authenticate."
}

# Step 1: Run the daily pipeline
Write-Log "Running daily pipeline..."
Set-Location $ScriptDir
$PipelineOutput = & $Python scripts/run_daily_pipeline.py 2>&1
$PipelineExit = $LASTEXITCODE
$PipelineOutput | ForEach-Object { Write-Log $_ }

if ($PipelineExit -eq 0) {
    $Status = 'SUCCESS'
    Write-Log "Pipeline completed successfully"
} else {
    $Status = 'FAILED'
    Write-Log "Pipeline failed with exit code $PipelineExit"
}

# Step 2: Read summary from JSON
$TotalTickets = 0
$TotalFollowUp = 0
$DateRange = 'N/A'
try {
    $JsonPath = Join-Path $ScriptDir 'scripts\mx_daily_report_data.json'
    $Data = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $Summary = $Data.summary
    $TotalTickets = $Summary.total_tickets
    $TotalFollowUp = $Summary.total_follow_up
    $DateRange = $Summary.date_range
    Write-Log "Summary: Tickets=$TotalTickets, FollowUp=$TotalFollowUp, Range=$DateRange"
} catch {
    Write-Log "Warning: Could not read summary JSON - $_"
}

# Step 3: Send DingTalk notification to Amiee
Write-Log "Sending DingTalk notification to Amiee..."

if ($Status -eq 'SUCCESS') {
    $MsgTitle = "MX Support Daily Report - $DateRange"
    $MsgText = "## MX Support Daily Report`n`n- Date: $DateRange`n- Total Tickets: $TotalTickets`n- Needs Follow Up: $TotalFollowUp`n- Status: $Status"
} else {
    $MsgTitle = "MX Support Daily Report - FAILED"
    $MsgText = "## MX Support Daily Report Failed`n`n- Date: $DateRange`n- Status: FAILED (exit code: $PipelineExit)`n`nPlease check log: $LogFile"
}

$DwsOutput = & $Dws chat message send --user $AmieeUserId --title $MsgTitle --text $MsgText --format json --yes 2>&1
$DwsExit = $LASTEXITCODE
$DwsOutput | ForEach-Object { Write-Log $_ }

if ($DwsExit -eq 0) {
    Write-Log "DingTalk notification sent to Amiee successfully"
} else {
    Write-Log "Failed to send DingTalk notification (exit code: $DwsExit)"
}

Write-Log "Scheduled task completed"
Write-Log "============================================================"
