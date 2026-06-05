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

Return author handle, date if available, one-line summary, URL, and mark direct evidence vs unverified claims.
"@
} else {
$prompt = @"
Use X search in cost-first mode. Use exactly one X keyword/latest search query. Do not run semantic search, user search, thread fetch, or follow-up searches unless the user provided a specific thread URL.
Search for up to $MaxResults recent X posts about:
$Query

Return concise findings with author handle, date if available, one-line summary, and URL. If no direct matches are found, say so and include the closest matches.
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
  reasoning = @{ effort = "low" }
  max_output_tokens = $MaxOutputTokens
} | ConvertTo-Json -Depth 10

$headers = @{
  Authorization = "Bearer $env:XAI_API_KEY"
  "Content-Type" = "application/json"
}

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "https://api.x.ai/v1/responses" `
  -Headers $headers `
  -Body $payload `
  -TimeoutSec 120

$texts = @()
foreach ($item in $response.output) {
  if ($item.type -eq "message") {
    foreach ($content in $item.content) {
      if ($content.text) { $texts += $content.text }
    }
  }
}

$toolCalls = @($response.output | Where-Object { $_.type -eq "custom_tool_call" } | Select-Object name,input,status)

[PSCustomObject]@{
  mode = $Mode
  answer = ($texts -join "`n")
  x_search_calls = $response.usage.server_side_tool_usage_details.x_search_calls
  total_tokens = $response.usage.total_tokens
  tool_calls = $toolCalls
} | ConvertTo-Json -Depth 8
