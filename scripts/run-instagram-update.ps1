param(
  [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [int]$RetryDelaySeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$logsDirectory = Join-Path $RepoPath "logs\instagram-update"
if (-not (Test-Path $logsDirectory)) {
  New-Item -ItemType Directory -Force -Path $logsDirectory | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $logsDirectory "$timestamp.log"

function Write-Log {
  param([string]$Message)

  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Add-Content -Path $logPath -Value $line -Encoding UTF8
  Write-Output $line
}

function Invoke-JsonScript {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath
  )

  $raw = & powershell.exe -ExecutionPolicy Bypass -File $ScriptPath 2>&1
  $exitCode = $LASTEXITCODE
  $outputText = ($raw -join [Environment]::NewLine).Trim()

  if ($exitCode -ne 0) {
    throw $outputText
  }

  if ([string]::IsNullOrWhiteSpace($outputText)) {
    throw "Script returned no output: $ScriptPath"
  }

  # Native commands may add transport messages around the script's JSON output.
  $jsonStart = $outputText.IndexOf("{")
  $jsonEnd = $outputText.LastIndexOf("}")
  if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) {
    throw "Script returned invalid JSON: $ScriptPath`n$outputText"
  }

  $jsonText = $outputText.Substring($jsonStart, $jsonEnd - $jsonStart + 1)
  return $jsonText | ConvertFrom-Json
}

$updateScriptPath = Join-Path $PSScriptRoot "update-instagram-json.ps1"
$publishScriptPath = Join-Path $PSScriptRoot "push-instagram-update.ps1"
Write-Log "Instagram update job started."
Write-Log "Repository: $RepoPath"

$updateResult = Invoke-JsonScript -ScriptPath $updateScriptPath
Write-Log "Updater status: $($updateResult.status) / source: $($updateResult.source)"
if ($updateResult.url) {
  Write-Log "Post URL: $($updateResult.url)"
}

if ($updateResult.status -eq "fallback" -and $updateResult.retryable -eq $true) {
  Write-Log "Retryable fallback detected. Waiting $RetryDelaySeconds seconds before one retry."
  Start-Sleep -Seconds $RetryDelaySeconds
  $updateResult = Invoke-JsonScript -ScriptPath $updateScriptPath
  Write-Log "Retry updater status: $($updateResult.status) / source: $($updateResult.source)"
  if ($updateResult.url) {
    Write-Log "Retry post URL: $($updateResult.url)"
  }
}

$publishResult = $null
if ($updateResult.status -eq "ok") {
  Write-Log "Instagram data is valid. Starting GitHub publish."
  $publishResult = Invoke-JsonScript -ScriptPath $publishScriptPath
  Write-Log "Publish status: $($publishResult.status)"
  if ($publishResult.commit) {
    Write-Log "Commit: $($publishResult.commit)"
  }
}
else {
  Write-Log "Publish skipped because the Instagram update did not succeed."
}

$summary = [pscustomobject]@{
  ranAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  update = $updateResult
  publish = $publishResult
  log = $logPath
}

$summaryJson = $summary | ConvertTo-Json -Depth 10
Add-Content -Path $logPath -Value $summaryJson -Encoding UTF8
$summaryJson
