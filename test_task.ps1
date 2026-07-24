$task = Get-ScheduledTask -TaskName 'MX Support Daily Report'
$task | Start-ScheduledTask
Write-Host "Task started. Waiting for completion..."
Start-Sleep -Seconds 5
$info = Get-ScheduledTaskInfo -TaskName 'MX Support Daily Report'
Write-Host "Last Run Time: $($info.LastRunTime)"
Write-Host "Last Result: $($info.LastTaskResult)"
