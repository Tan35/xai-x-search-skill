---
name: xai-x-search
description: Use this skill when an agent needs to search X/Twitter through the xAI Responses API x_search tool, verify current X posts, fetch recent discussion, compare claims on X, or use Grok's internal X search capabilities such as x_keyword_search, x_semantic_search, x_user_search, and x_thread_fetch. The SKILL.md is self-contained and includes cost controls plus direct API examples.
---

# xAI X Search

Use xAI's public Responses API tool:

```json
{ "type": "x_search" }
```

Do not call internal tool names directly. Grok may internally call `x_keyword_search`, `x_semantic_search`, `x_user_search`, or `x_thread_fetch`, but the public API entrypoint is `x_search`.

## Requirements

- Read the API key from `XAI_API_KEY`. Never hard-code or print the key.
- Use `https://api.x.ai/v1/responses`.
- Prefer `grok-4.3` unless the user specifies another available xAI model.
- If the user pasted a key in chat, recommend rotating it after testing.

## Cost Controls

`x_search` is charged per server-side tool call, plus model tokens. Keep calls narrow by default.

- Set `max_tool_calls` to `1` unless the user explicitly asks for broad search.
- Use `reasoning.effort: "low"` for lookup tasks.
- Set `max_output_tokens` between `500` and `1200`.
- Add date bounds with `from_date` and `to_date` whenever possible.
- Ask for a small result count in the prompt, such as "Return up to 3 findings".
- Avoid broad prompts like "search everything" or "analyze all discussion".

## Self-Contained PowerShell Use

Agents that only read `SKILL.md` should use this inline PowerShell pattern. Replace `$query`, `$fromDate`, and `$toDate`; do not print the API key.

```powershell
$query = "Grok CLI X search tools"
$fromDate = "2026-06-01"
$toDate = "2026-06-05"
$maxResults = 3

if (-not $env:XAI_API_KEY) {
  throw "Set XAI_API_KEY before calling xAI X Search."
}

$headers = @{
  Authorization = "Bearer $env:XAI_API_KEY"
  "Content-Type" = "application/json"
}

$payload = @{
  model = "grok-4.3"
  input = @(
    @{
      role = "user"
      content = "Use X search. Search for up to $maxResults recent X posts about: $query. Return author handle, date if available, one-line summary, and URL. If no direct matches are found, say so and include closest matches."
    }
  )
  tools = @(
    @{
      type = "x_search"
      from_date = $fromDate
      to_date = $toDate
    }
  )
  max_tool_calls = 1
  reasoning = @{ effort = "low" }
  max_output_tokens = 800
} | ConvertTo-Json -Depth 10

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

[PSCustomObject]@{
  answer = ($texts -join "`n")
  x_search_calls = $response.usage.server_side_tool_usage_details.x_search_calls
  total_tokens = $response.usage.total_tokens
  tool_calls = @($response.output | Where-Object { $_.type -eq "custom_tool_call" } | Select-Object name,input,status)
} | ConvertTo-Json -Depth 8
```

## Direct API Shape

```json
{
  "model": "grok-4.3",
  "input": [
    {
      "role": "user",
      "content": "Use X search. Search for up to 3 recent X posts about <topic>. Return author handle, date, one-line summary, and URL."
    }
  ],
  "tools": [
    {
      "type": "x_search",
      "from_date": "YYYY-MM-DD",
      "to_date": "YYYY-MM-DD"
    }
  ],
  "max_tool_calls": 1,
  "reasoning": { "effort": "low" },
  "max_output_tokens": 800
}
```

## Interpreting Results

In the response:

- Final answer text is usually in `output[]` items where `type == "message"`.
- Internal search calls appear as `custom_tool_call` items.
- Usage is in `usage.server_side_tool_usage_details.x_search_calls`.
- `num_sources_used` can be `0` even when X search worked; inspect tool calls and final URLs too.

## Failure Handling

- `401` or `403`: key is invalid, revoked, or lacks permission.
- `429`: rate limit or quota issue.
- No results: retry once with a simpler keyword query and the same `max_tool_calls` limit.
- If a request times out, narrow the query and lower `max_output_tokens`.

## Optional Bundled Script

Some agents can read files under `scripts/`. If available, they may use:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\xai-x-search\scripts\xai_x_search.ps1" `
  -Query "Grok CLI X search tools" `
  -FromDate "2026-06-01" `
  -ToDate "2026-06-05" `
  -MaxToolCalls 1 `
  -MaxResults 3
```

Do not depend on this script when the agent can only access `SKILL.md`; use the self-contained pattern above instead.
