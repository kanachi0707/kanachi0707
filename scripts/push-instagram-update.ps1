param(
  [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string[]]$Files = @("instagram-latest.json", "instagram-latest.js"),
  [string]$CommitMessage = "Update Instagram latest"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [switch]$AllowFailure
  )

  $allArguments = @("-c", "safe.directory=$RepoPath", "-C", $RepoPath) + $Arguments
  $output = & git @allArguments 2>&1
  $exitCode = $LASTEXITCODE

  if (-not $AllowFailure -and $exitCode -ne 0) {
    $message = if ($output) { ($output -join [Environment]::NewLine) } else { "git command failed." }
    throw $message
  }

  [pscustomobject]@{
    ExitCode = $exitCode
    Output = @($output)
  }
}

function Get-TrackedFileContent {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  $showResult = Invoke-Git -Arguments @("show", "HEAD:$RelativePath") -AllowFailure
  if ($showResult.ExitCode -ne 0) {
    return $null
  }

  return ($showResult.Output -join [Environment]::NewLine)
}

function ConvertTo-ComparableJson {
  param(
    [Parameter(Mandatory = $true)]
    [string]$JsonText
  )

  $object = $JsonText | ConvertFrom-Json
  $comparable = [ordered]@{}

  foreach ($property in $object.PSObject.Properties) {
    if ($property.Name -ne "updatedAt") {
      $comparable[$property.Name] = $property.Value
    }
  }

  return ($comparable | ConvertTo-Json -Depth 10 -Compress)
}

$relativeFiles = @($Files | ForEach-Object { $_.Replace("/", "\") })
$branchResult = Invoke-Git -Arguments @("branch", "--show-current")
$branch = ($branchResult.Output -join "").Trim()
if ($branch -ne "main") {
  throw "Instagram auto-publish must run on main. Current branch: $branch"
}

$statusResult = Invoke-Git -Arguments (@("status", "--porcelain", "--") + $relativeFiles)
$hasTargetChanges = @($statusResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
$changeStatus = "no_changes"
$commitHash = ""
$committed = $false

if ($hasTargetChanges) {
  $jsonPath = Join-Path $RepoPath "instagram-latest.json"
  $currentJson = Get-Content -Raw $jsonPath
  $trackedJson = Get-TrackedFileContent -RelativePath "instagram-latest.json"
  $contentChanged = $true

  if ($trackedJson -ne $null) {
    $currentComparable = ConvertTo-ComparableJson -JsonText $currentJson
    $trackedComparable = ConvertTo-ComparableJson -JsonText $trackedJson
    $contentChanged = $currentComparable -ne $trackedComparable
  }

  if ($contentChanged) {
    Invoke-Git -Arguments (@("add", "--") + $relativeFiles) | Out-Null

    $commitResult = Invoke-Git -Arguments @("commit", "-m", $CommitMessage)
    foreach ($line in $commitResult.Output) {
      if ($line -match "^\[(?:.+?)\s+([0-9a-f]{7,40})\]") {
        $commitHash = $Matches[1]
        break
      }
    }

    $committed = $true
    $changeStatus = "committed"
  }
  else {
    $changeStatus = "updated_at_only"
  }
}

$aheadResult = Invoke-Git -Arguments @("rev-list", "--count", "origin/main..HEAD")
$aheadCount = [int](($aheadResult.Output -join "").Trim())
if ($aheadCount -eq 0) {
  [pscustomobject]@{
    status = $changeStatus
    committed = $committed
    pushed = $false
    commit = $commitHash
    files = $relativeFiles
  } | ConvertTo-Json -Depth 5
  exit 0
}

$pushResult = Invoke-Git -Arguments @("push", "origin", "HEAD:main") -AllowFailure
$usedRebase = $false

if ($pushResult.ExitCode -ne 0) {
  $pushText = ($pushResult.Output -join [Environment]::NewLine)

  if ($pushText -match "fetch first|non-fast-forward|rejected") {
    $usedRebase = $true
    Invoke-Git -Arguments @("fetch", "origin") | Out-Null
    Invoke-Git -Arguments @("rebase", "--autostash", "origin/main") | Out-Null
    $pushResult = Invoke-Git -Arguments @("push", "origin", "HEAD:main")
  } else {
    throw $pushText
  }
}

[pscustomobject]@{
  status = "pushed"
  committed = $committed
  pushed = $true
  usedRebase = $usedRebase
  commit = $commitHash
  files = $relativeFiles
} | ConvertTo-Json -Depth 5
