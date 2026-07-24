# ============================================================
#  Register Windows Scheduled Task: MX Support Morning Report
#  Trigger: daily at 08:00 (local system time)
#
#  Run this script from its own directory:
#    powershell -File register_morning_task.ps1
# ============================================================

$taskName = 'MX Support Morning Report'
$psScript = Join-Path $PSScriptRoot 'run_scheduled.ps1'
$workDir = $PSScriptRoot

# Remove existing task
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Trigger: daily at 08:00 local time
$trigger = New-ScheduledTaskTrigger -Daily -At '08:00'

# Action: run PowerShell script
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$psScript`"" -WorkingDirectory $workDir

# Settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

# Register
Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings -Description 'MX Support Morning Report: 08:00 - Freshdesk -> Excel -> DingTalk AI Table + Notify' -Force

Write-Host "Task '$taskName' registered!"
Get-ScheduledTask -TaskName $taskName | Format-List TaskName, State
Get-ScheduledTaskInfo -TaskName $taskName | Format-List NextRunTime
