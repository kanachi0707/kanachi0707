param(
  [string]$Username = "kanachi0707",
  [string]$JsonPath = (Join-Path $PSScriptRoot "..\instagram-latest.json"),
  [string]$FallbackUrl = "https://www.instagram.com/p/DVM3FVxErTp/",
  [switch]$KeepExistingCaption
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-InstagramUrl {
  param([string]$Url)

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return ""
  }

  if ($Url.EndsWith('/')) {
    return $Url
  }

  return "$Url/"
}

function Get-InstagramProfileData {
  param([string]$Username)

  $apiUrl = "https://www.instagram.com/api/v1/users/web_profile_info/?username=$Username"
  $tempPath = [System.IO.Path]::GetTempFileName()

  try {
    $curlOutput = & curl.exe -sS -f -L $apiUrl -H "x-ig-app-id: 936619743392459" -H "User-Agent: Mozilla/5.0" --output $tempPath 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "Instagram profile request failed: $($curlOutput -join ' ')"
    }

    # Reading curl output as UTF-8 from disk avoids Windows PowerShell's console decoding.
    $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $raw = [System.IO.File]::ReadAllText($tempPath, $utf8)

    if ([string]::IsNullOrWhiteSpace($raw)) {
      throw "Instagram profile endpoint returned empty response."
    }

    return $raw | ConvertFrom-Json
  }
  finally {
    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
  }
}

function Get-LatestInstagramPost {
  param([string]$Username)

  $payload = Get-InstagramProfileData -Username $Username
  $edges = $payload.data.user.edge_owner_to_timeline_media.edges

  if (-not $edges -or $edges.Count -lt 1) {
    throw "No Instagram posts found in profile response."
  }

  $node = $null
  foreach ($edge in $edges) {
    $pinnedCount = 0
    if ($edge.node.pinned_for_users) {
      $pinnedCount = $edge.node.pinned_for_users.Count
    }

    if ($pinnedCount -eq 0) {
      $node = $edge.node
      break
    }
  }

  if (-not $node) {
    $node = $edges[0].node
  }

  if (-not $node.shortcode) {
    throw "Latest Instagram post shortcode was missing."
  }

  $caption = ""
  if ($node.edge_media_to_caption.edges -and $node.edge_media_to_caption.edges.Count -gt 0) {
    $caption = [string]$node.edge_media_to_caption.edges[0].node.text
  }

  [pscustomobject]@{
    url = Normalize-InstagramUrl("https://www.instagram.com/p/$($node.shortcode)")
    caption = $caption
    takenAt = if ($node.taken_at_timestamp) { [DateTimeOffset]::FromUnixTimeSeconds([int64]$node.taken_at_timestamp).ToString("yyyy-MM-ddTHH:mm:ssK") } else { "" }
  }
}

$existingData = $null
if (Test-Path $JsonPath) {
  $existingData = Get-Content -Raw $JsonPath | ConvertFrom-Json
}

try {
  $latestPost = Get-LatestInstagramPost -Username $Username
  $caption = if ($KeepExistingCaption -and $existingData -and -not [string]::IsNullOrWhiteSpace($existingData.caption)) {
    [string]$existingData.caption
  } else {
    [string]$latestPost.caption
  }

  $payload = [ordered]@{
    url = $latestPost.url
    caption = $caption
    updatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    fallbackUrl = Normalize-InstagramUrl($FallbackUrl)
    source = "instagram-web-profile-api"
    status = "ok"
  }

  if ($latestPost.takenAt) {
    $payload["postTakenAt"] = $latestPost.takenAt
  }
}
catch {
  $errorMessage = $_.Exception.Message
  $retryable = $false

  if ($errorMessage -match "empty response|timed out|timeout|connection|connect|temporar|429|5\d\d") {
    $retryable = $true
  }

  $payload = [ordered]@{
    url = if ($existingData -and $existingData.url) { Normalize-InstagramUrl([string]$existingData.url) } else { Normalize-InstagramUrl($FallbackUrl) }
    caption = if ($existingData -and $existingData.caption) { [string]$existingData.caption } else { "" }
    updatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    fallbackUrl = Normalize-InstagramUrl($FallbackUrl)
    source = "fallback"
    status = "fallback"
    error = $errorMessage
    retryable = $retryable
  }
}

$directory = Split-Path -Parent $JsonPath
if (-not (Test-Path $directory)) {
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonPath -Encoding UTF8
$jsPath = Join-Path (Split-Path -Parent $JsonPath) "instagram-latest.js"
$jsPayload = "window.__INSTAGRAM_LATEST_POST__ = " + ($payload | ConvertTo-Json -Depth 6) + ";"
Set-Content -Path $jsPath -Value $jsPayload -Encoding UTF8
$payload | ConvertTo-Json -Depth 6
