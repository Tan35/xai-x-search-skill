param(
  [Parameter(Mandatory = $true)]
  [string]$Query,

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

$prompt = @"
Use X search. Search for up to $MaxResults recent X posts about:
$Query

Return concise findings with author handle, date if available, one-line summary, and URL. If no direct matches are found, say so and include the closest matches.
"@

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
  answer = ($texts -join "`n")
  x_search_calls = $response.usage.server_side_tool_usage_details.x_search_calls
  total_tokens = $response.usage.total_tokens
  tool_calls = $toolCalls
} | ConvertTo-Json -Depth 8
