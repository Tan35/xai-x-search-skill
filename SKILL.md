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
- Prefer **`grok-4.3`** unless the user names another model. It follows cost-control prompts well and supports `reasoning.effort`.
- **`grok-4.5`**: stronger, higher token price. Use when the user asks or needs more reasoning depth — not the default for a cheap link check.
- **`grok-4.20` variants**: support `x_search`, but **do not** pass `reasoning: { effort: ... }` (HTTP 400). Omit the `reasoning` block.
- Avoid **`grok-build-0.1`** for general search; it often multi-searches and ignores tight cost prompts.
- If the user pasted a key in chat, recommend rotating it after testing.

## Mode Selection

Choose one mode before calling the API:

- **Cost-first mode**: cheap, quick check, one search, verify lightly, or no preference. **Default.**
- **Quality-first mode**: comprehensive, deep search, don't worry about cost, find all relevant posts, compare sources, threads/users/context.

If the user gives no preference, use **cost-first** and say so. Only ask to clarify when stakes are high or they clearly want exhaustive coverage.

## Cost Controls

**Billing unit is not the API request**

`x_search` is billed per **successful internal tool invocation**, not per HTTP request. One `POST /v1/responses` may run several X searches, each billed (list price **$0.005**). `max_tool_calls: 1` is **advisory** — always combine it with a strict prompt.

```
Your 1 API request
    └── Grok decides internally
            ├── x_keyword_search(...)  → billed $0.005
            └── x_semantic_search(...) → billed $0.005  ← extra charge
```

**List pricing (verify on docs; rates change):**

| Component | Rate |
|---|---|
| `x_search` | $5.00 / 1,000 ($0.005 each) |
| Input / output (`grok-4.3` / `grok-4.20`) | $1.25 / $2.50 per 1M |
| Input / output (`grok-4.5`) | $2.00 / $6.00 per 1M |

Rough benchmarks (`grok-4.3`): cost-first + strict prompt ≈ **$0.012–$0.015** (1 call); quality-first with ~3 calls ≈ **$0.025–$0.035**. Extra tool calls dominate small token differences.

**Parameter reference:**

| Parameter | Cost-first | Quality-first |
|---|---|---|
| `max_tool_calls` | `1` | `3`–`6` |
| `max_output_tokens` | `500`–`900` | `1200`–`2200` |
| `reasoning.effort` | `"low"` if supported | `"low"` if supported |

Additional rules:

- Add `from_date` / `to_date` whenever possible.
- Use `allowed_x_handles` **or** `excluded_x_handles`, never both (HTTP 400).
- `enable_image_understanding` / `enable_video_understanding` only if the user asks about media (extra tokens).

## Mode Steps

### Cost-First Mode

1. One compact keyword query (exact phrases + 1–2 synonyms).
2. Date bounds if given; otherwise the narrowest reasonable recent window.
3. `max_tool_calls: 1`, `max_output_tokens: 800`; add `reasoning.effort: "low"` only if the model supports it.
4. Prompt must include: *Use exactly one X keyword/latest search query. Do not run semantic search, user search, thread fetch, or follow-up searches unless the user provided a specific thread URL. Return up to 3 findings: author handle, date, one-line summary, URL. For topical relevance use strong match vs loose match (not fact-check language).*
5. Return the answer, URLs, and `x_search_calls` from usage.

### Quality-First Mode

1. Semantic search for recall + keyword/latest for precision.
2. User/thread fetch when handles or status URLs appear.
3. `max_tool_calls: 5`, `max_output_tokens: 1800`; `reasoning.effort: "low"` if supported.
4. Prompt: *Use semantic search plus keyword/latest search, and fetch user/thread context if clearly relevant. Return up to 8 findings: author handle, date, one-line summary, URL, and mark strong match vs loose match (topical relevance only).*
5. Return findings, what is well supported vs thin, and `x_search_calls`.

## Self-Contained PowerShell Use

Agents that only read `SKILL.md` should use this pattern. Do not print the API key.

```powershell
$mode = "cost" # "cost" or "quality"
$query = "Grok CLI X search tools"
$fromDate = "2026-06-01"
$toDate = "2026-06-05"
$model = "grok-4.3"

if (-not $env:XAI_API_KEY) {
  throw "Set XAI_API_KEY before calling xAI X Search."
}

if ($mode -eq "quality") {
  $maxResults = 8
  $maxToolCalls = 5
  $maxOutputTokens = 1800
  $searchInstruction = "Use X search in quality-first mode. Use semantic search plus keyword/latest search, and fetch user/thread context if it is clearly relevant. Search for up to $maxResults relevant X posts about: $query. Return author handle, date if available, one-line summary, URL, and mark strong match vs loose match (topical relevance only)."
} else {
  $maxResults = 3
  $maxToolCalls = 1
  $maxOutputTokens = 800
  $searchInstruction = "Use X search in cost-first mode. Use exactly one X keyword/latest search query. Do not run semantic search, user search, thread fetch, or follow-up searches unless the user provided a specific thread URL. Search for up to $maxResults recent X posts about: $query. Return author handle, date if available, one-line summary, and URL. Prefer strong matches; if only weak ones exist, mark them loose match."
}

$headers = @{
  Authorization = "Bearer $env:XAI_API_KEY"
  "Content-Type" = "application/json"
}

$payload = @{
  model = $model
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
  max_output_tokens = $maxOutputTokens
}

# grok-4.20* rejects reasoning.effort
if ($model -notmatch '4\.20' -and $model -notmatch 'build') {
  $payload.reasoning = @{ effort = "low" }
}

$payloadJson = $payload | ConvertTo-Json -Depth 10

try {
  $response = Invoke-RestMethod `
    -Method Post `
    -Uri "https://api.x.ai/v1/responses" `
    -Headers $headers `
    -Body $payloadJson `
    -TimeoutSec 120
} catch {
  if (-not $_.Exception.Response) {
    Write-Error "Connection failed — DNS, network, or TLS error."
  } else {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "xAI API returned HTTP ${statusCode}"
  }
  exit 1
}

$texts = @()
$toolCalls = @()
if ($response.output -is [array]) {
  foreach ($item in $response.output) {
    if ($item.type -eq "message" -and $item.content) {
      foreach ($content in $item.content) {
        if ($content.text) { $texts += $content.text }
      }
    }
  }
  $toolCalls = @($response.output | Where-Object { $_.type -eq "custom_tool_call" } | Select-Object name,input,status)
} elseif ($response.output -and $response.output.type -eq "message") {
  if ($response.output.content -and $response.output.content.text) {
    $texts += $response.output.content.text
  }
}

$xSearchCalls = if ($response.usage.server_side_tool_usage_details) {
  $response.usage.server_side_tool_usage_details.x_search_calls
} else { 0 }
$totalTokens = if ($response.usage.total_tokens) { $response.usage.total_tokens } else { 0 }

[PSCustomObject]@{
  answer = ($texts -join "`n")
  x_search_calls = $xSearchCalls
  total_tokens = $totalTokens
  tool_calls = $toolCalls
} | ConvertTo-Json -Depth 8
```

## Direct API Shape

Cost-first (omit `reasoning` for `grok-4.20*`):

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

Quality-first:

```json
{
  "model": "grok-4.3",
  "input": [
    {
      "role": "user",
      "content": "Use X search in quality-first mode. Use semantic search plus keyword/latest search, and fetch user/thread context if clearly relevant. Search for up to 8 relevant X posts about <topic>. Return author handle, date, one-line summary, URL, and mark strong match vs loose match (topical relevance only)."
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

- Final text: `output[]` items with `type == "message"`.
- Internal searches: often `custom_tool_call`.
- Billable count: `usage.server_side_tool_usage_details.x_search_calls`.
- If cost-first still multi-calls, report the real count and only re-run wider with user approval.
- `num_sources_used` can be `0` even when search worked; check tool calls and URLs.

## Failure Handling

- `400`: bad request, bad key format, or rejected payload (including unsupported `reasoning` on some models).
- `401` / `403`: missing, invalid, or revoked key.
- `429`: rate limit or quota.
- Connection errors: no HTTP response — DNS/TLS/network.
- No results: one retry with a simpler keyword and the same `max_tool_calls`.
- Timeouts: narrower query, lower `max_output_tokens`.

## Optional Bundled Script

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\xai-x-search\scripts\xai_x_search.ps1" `
  -Query "Grok CLI X search tools" `
  -Mode cost `
  -FromDate "2026-06-01" `
  -ToDate "2026-06-05" `
  -MaxToolCalls 1 `
  -MaxResults 3
```

Prefer the inline pattern above when the agent cannot run `scripts/`.
