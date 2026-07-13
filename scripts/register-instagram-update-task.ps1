param(
  [string]$TaskName = "Instagram Portfolio Update",
  [string]$Time = "12:00"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runnerPath = Join-Path $PSScriptRoot "run-instagram-update.ps1"

$triggerTime = [DateTime]::Today.Add([TimeSpan]::Parse($Time))
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`"" -WorkingDirectory $repoPath
$trigger = New-ScheduledTaskTrigger -Daily -At $triggerTime
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Update the latest Instagram post and publish it to the kanachi portfolio site." -Force | Out-Null

[pscustomobject]@{
  task = $TaskName
  time = $Time
  runner = $runnerPath
  repository = $repoPath
  status = "registered"
} | ConvertTo-Json -Depth 5
