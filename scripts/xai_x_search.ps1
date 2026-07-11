# Optional local helper (Windows / PowerShell).
# Agents should follow SKILL.md (curl/JSON) instead of requiring this file.

param(
  [Parameter(Mandatory = $true)]
  [string]$Query,

  [ValidateSet("cost", "quality")]
  [string]$Mode = "cost",

  [string]$FromDate,
  [string]$ToDate,
  [string]$Model = "grok-4.3",
  [int]$MaxToolCalls = 1,
  [int]$MaxResults = 3,
  [int]$MaxOutputTokens = 800
)

$ErrorActionPreference = "Stop"

if (-not $env:XAI_API_KEY) {
  throw "Set XAI_API_KEY before running this script."
}

$tool = @{ type = "x_search" }
if ($FromDate) { $tool.from_date = $FromDate }
if ($ToDate) { $tool.to_date = $ToDate }

if ($Mode -eq "quality") {
  if ($PSBoundParameters.ContainsKey("MaxToolCalls") -eq $false) { $MaxToolCalls = 5 }
  if ($PSBoundParameters.ContainsKey("MaxResults") -eq $false) { $MaxResults = 8 }
  if ($PSBoundParameters.ContainsKey("MaxOutputTokens") -eq $false) { $MaxOutputTokens = 1800 }
}

if ($Mode -eq "quality") {
  $prompt = @"
Use X search in quality-first mode. Use semantic search plus keyword/latest search, and fetch user/thread context if it is clearly relevant.
Search for up to $MaxResults relevant X posts about:
$Query

Return author handle, date if available, one-line summary, URL, and mark strong match vs loose match (topical relevance only, not fact-check).
"@
} else {
$prompt = @"
Use X search in cost-first mode. Use exactly one X keyword/latest search query. Do not run semantic search, user search, thread fetch, or follow-up searches unless the user provided a specific thread URL.
Search for up to $MaxResults recent X posts about:
$Query

Return concise findings with author handle, date if available, one-line summary, and URL. Prefer strong matches; if only weak ones exist, mark them loose match.
"@
}

$payload = @{
  model = $Model
  input = @(
    @{
      role = "user"
      content = $prompt
    }
  )
  tools = @($tool)
  max_tool_calls = $MaxToolCalls
  max_output_tokens = $MaxOutputTokens
}

# grok-4.20* and coding builds reject reasoning.effort
if ($Model -notmatch '4\.20' -and $Model -notmatch 'build') {
  $payload.reasoning = @{ effort = "low" }
}

$payloadJson = $payload | ConvertTo-Json -Depth 10

$headers = @{
  Authorization = "Bearer $env:XAI_API_KEY"
  "Content-Type" = "application/json"
}

try {
  $response = Invoke-RestMethod `
    -Method Post `
    -Uri "https://api.x.ai/v1/responses" `
    -Headers $headers `
    -Body $payloadJson `
    -TimeoutSec 120
} catch {
  # Non-HTTP errors (DNS, connection refused, TLS) have no Response object
  if (-not $_.Exception.Response) {
    $errorInfo = [PSCustomObject]@{
      mode = $Mode
      error = $true
      http_status = 0
      message = "Connection failed — DNS, network, or TLS error. Check connectivity to api.x.ai."
      detail = $_.Exception.Message
      x_search_calls = 0
      total_tokens = 0
      tool_calls = @()
    } | ConvertTo-Json -Depth 4
    Write-Output $errorInfo
    exit 1
  }

  $statusCode = $_.Exception.Response.StatusCode.value__
  $errorBody = ""
  try {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $errorBody = $reader.ReadToEnd()
    $reader.Close()
  } catch {}

  $errorInfo = [PSCustomObject]@{
    mode = $Mode
    error = $true
    http_status = $statusCode
    message = switch ($statusCode) {
      400 { "Bad request — API key may be invalid, malformed, or the endpoint rejected the payload. Check your key format and request body." }
      401 { "Unauthorized — API key is missing or invalid." }
      403 { "Forbidden — API key lacks permission or has been revoked." }
      429 { "Rate limited — too many requests. Wait and retry." }
      default { "HTTP ${statusCode} — request failed." }
    }
    detail = if ($errorBody) { $errorBody } else { $_.Exception.Message }
    x_search_calls = 0
    total_tokens = 0
    tool_calls = @()
  } | ConvertTo-Json -Depth 4

  Write-Output $errorInfo
  exit 1
}

# Defensive parse: response.output may be absent or not an array
$texts = @()
$toolCalls = @()
$xSearchCalls = 0
$totalTokens = 0

if ($response.output -is [array]) {
  foreach ($item in $response.output) {
    if ($item.type -eq "message") {
      if ($item.content -is [array]) {
        foreach ($content in $item.content) {
          if ($content.text) { $texts += $content.text }
        }
      }
    }
  }
  $toolCalls = @($response.output | Where-Object { $_.type -eq "custom_tool_call" } | Select-Object name,input,status)
} elseif ($response.output -and $response.output.type -eq "message") {
  if ($response.output.content -and $response.output.content.text) {
    $texts += $response.output.content.text
  }
}

if ($response.usage) {
  $xSearchCalls = if ($response.usage.server_side_tool_usage_details) {
    $response.usage.server_side_tool_usage_details.x_search_calls
  } else { 0 }
  $totalTokens = if ($response.usage.total_tokens) { $response.usage.total_tokens } else { 0 }
}

# Post-hoc tool_calls check: warn when actual server-side calls exceed limit
if ($xSearchCalls -gt $MaxToolCalls) {
  $warnings = @("WARNING: max_tool_calls was set to ${MaxToolCalls} but xAI made ${xSearchCalls} server-side search calls. Cost may exceed budget. Add prompt-level constraints or reduce the search scope.")
} else {
  $warnings = @()
}

[PSCustomObject]@{
  mode = $Mode
  answer = ($texts -join "`n")
  x_search_calls = $xSearchCalls
  total_tokens = $totalTokens
  tool_calls = $toolCalls
  max_tool_calls_limit = $MaxToolCalls
  actual_tool_calls = $xSearchCalls
  warnings = $warnings
} | ConvertTo-Json -Depth 8
