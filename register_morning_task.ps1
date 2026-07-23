$taskName = 'MX Support Morning Report'
$psScript = 'C:\Users\GL\.qoderworkcn\workspace\mr2y9wr285i946sj\repo\mx-support-daily-report\run_scheduled.ps1'
$workDir = 'C:\Users\GL\.qoderworkcn\workspace\mr2y9wr285i946sj\repo\mx-support-daily-report'

# Remove existing task
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Trigger: daily at 08:00 Beijing time
$trigger = New-ScheduledTaskTrigger -Daily -At '08:00'

# Action: run PowerShell script
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$psScript`"" -WorkingDirectory $workDir

# Settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

# Register
Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings -Description 'MX Support Morning Report: 08:00 Beijing time - Freshdesk -> Excel -> DingTalk AI Table + Notify Amiee' -Force

Write-Host "Task '$taskName' registered!"
Get-ScheduledTask -TaskName $taskName | Format-List TaskName, State
Get-ScheduledTaskInfo -TaskName $taskName | Format-List NextRunTime
