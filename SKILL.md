---
name: xai-x-search
description: Use this skill when an agent needs to search X/Twitter through the xAI Responses API x_search tool, verify current X posts, fetch recent discussion, compare claims on X, or use Grok's internal X search capabilities such as x_keyword_search, x_semantic_search, x_user_search, and x_thread_fetch. The SKILL.md is self-contained and supports cost-first and quality-first search modes.
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

## Mode Selection

Choose one mode before calling the API:

- **Cost-first mode**: Use when the user says cheap, low cost, quick check, one search, verify lightly, or gives no preference. This is the default.
- **Quality-first mode**: Use when the user says comprehensive, high quality, deep search, don't worry about cost, find all relevant posts, compare sources, or asks for threads/users/context.

If the user gives no preference, default to **cost-first mode** and mention that assumption. Ask a clarifying question only when the task is high stakes or the user clearly expects exhaustive coverage.

## Cost Controls

`x_search` is charged per server-side tool call, plus model tokens. Keep calls narrow by default.

- Public `max_tool_calls` may not fully prevent Grok from making multiple internal X searches. In cost-first mode, also instruct the model to use exactly one keyword/latest search and no semantic follow-up.
- Set `max_tool_calls` to `1` in cost-first mode.
- Use `max_tool_calls` between `3` and `6` in quality-first mode.
- Use `reasoning.effort: "low"` for lookup tasks.
- Set `max_output_tokens` between `500` and `900` for cost-first mode.
- Set `max_output_tokens` between `1200` and `2200` for quality-first mode.
- Add date bounds with `from_date` and `to_date` whenever possible.
- Ask for a small result count in the prompt, such as "Return up to 3 findings".
- Avoid broad prompts like "search everything" or "analyze all discussion".

## Mode Steps

### Cost-First Mode

Use this when minimizing spend matters more than recall.

1. Convert the user's request into one compact keyword query with exact phrases and 1-2 synonyms.
2. Add date bounds if the user supplied them; otherwise use the narrowest reasonable recent window.
3. Ask for 3-5 findings.
4. Tell the model: "Use exactly one X keyword/latest search query. Do not run semantic search, user search, thread fetch, or follow-up searches unless required to answer a user-provided specific URL/thread."
5. Return URLs, short summaries, and usage.

### Quality-First Mode

Use this when recall, verification, or context matters more than cost.

1. Start with a semantic search for broad recall.
2. Add one keyword/latest search using exact phrases.
3. If specific handles or thread URLs appear, allow user search or thread fetch.
4. Ask for 5-10 findings, grouped by confidence or theme.
5. Return URLs, short summaries, what was directly supported, what remains unverified, and usage.

## Self-Contained PowerShell Use

Agents that only read `SKILL.md` should use this inline PowerShell pattern. Replace `$mode`, `$query`, `$fromDate`, and `$toDate`; do not print the API key.

```powershell
$mode = "cost" # "cost" or "quality"
$query = "Grok CLI X search tools"
$fromDate = "2026-06-01"
$toDate = "2026-06-05"

if (-not $env:XAI_API_KEY) {
  throw "Set XAI_API_KEY before calling xAI X Search."
}

if ($mode -eq "quality") {
  $maxResults = 8
  $maxToolCalls = 5
  $maxOutputTokens = 1800
  $searchInstruction = "Use X search in quality-first mode. Use semantic search plus keyword/latest search, and fetch user/thread context if it is clearly relevant. Search for up to $maxResults relevant X posts about: $query. Return author handle, date if available, one-line summary, URL, and mark direct evidence vs unverified claims."
} else {
  $maxResults = 3
  $maxToolCalls = 1
  $maxOutputTokens = 800
  $searchInstruction = "Use X search in cost-first mode. Use exactly one X keyword/latest search query. Do not run semantic search, user search, thread fetch, or follow-up searches unless the user provided a specific thread URL. Search for up to $maxResults recent X posts about: $query. Return author handle, date if available, one-line summary, and URL. If no direct matches are found, say so and include closest matches."
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
      content = $searchInstruction
    }
  )
  tools = @(
    @{
      type = "x_search"
      from_date = $fromDate
      to_date = $toDate
    }
  )
  max_tool_calls = $maxToolCalls
  reasoning = @{ effort = "low" }
  max_output_tokens = $maxOutputTokens
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

Cost-first payload:

```json
{
  "model": "grok-4.3",
  "input": [
    {
      "role": "user",
      "content": "Use X search in cost-first mode. Use exactly one X keyword/latest search query. Do not run semantic search, user search, thread fetch, or follow-up searches unless the user provided a specific thread URL. Search for up to 3 recent X posts about <topic>. Return author handle, date, one-line summary, and URL."
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

Quality-first payload:

```json
{
  "model": "grok-4.3",
  "input": [
    {
      "role": "user",
      "content": "Use X search in quality-first mode. Use semantic search plus keyword/latest search, and fetch user/thread context if clearly relevant. Search for up to 8 relevant X posts about <topic>. Return author handle, date, one-line summary, URL, and mark direct evidence vs unverified claims."
    }
  ],
  "tools": [
    {
      "type": "x_search",
      "from_date": "YYYY-MM-DD",
      "to_date": "YYYY-MM-DD"
    }
  ],
  "max_tool_calls": 5,
  "reasoning": { "effort": "low" },
  "max_output_tokens": 1800
}
```

## Interpreting Results

In the response:

- Final answer text is usually in `output[]` items where `type == "message"`.
- Internal search calls appear as `custom_tool_call` items.
- Usage is in `usage.server_side_tool_usage_details.x_search_calls`.
- If cost-first mode still produces multiple internal calls, tell the user the actual count and consider rerunning with a narrower exact-phrase query only if they approve the extra cost.
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
  -Mode cost `
  -FromDate "2026-06-01" `
  -ToDate "2026-06-05" `
  -MaxToolCalls 1 `
  -MaxResults 3
```

Do not depend on this script when the agent can only access `SKILL.md`; use the self-contained pattern above instead.
