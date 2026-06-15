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
- Prefer `grok-4.3` unless the user specifies another available xAI model. `grok-4.3` fully supports the `reasoning.effort` parameter and follows cost-control prompts best.
- If using `grok-4.20` variants (e.g., `grok-4.20-0309-reasoning`), **do not** pass the `reasoning` parameter, or the API will return HTTP 400.
- Avoid using coding models like `grok-build-0.1` for searches, as they may ignore prompt constraints and trigger excessive billable internal searches.
- If the user pasted a key in chat, recommend rotating it after testing.

## Mode Selection

Choose one mode before calling the API:

- **Cost-first mode**: Use when the user says cheap, low cost, quick check, one search, verify lightly, or gives no preference. This is the default.
- **Quality-first mode**: Use when the user says comprehensive, high quality, deep search, don't worry about cost, find all relevant posts, compare sources, or asks for threads/users/context.

If the user gives no preference, default to **cost-first mode** and mention that assumption. Ask a clarifying question only when the task is high stakes or the user clearly expects exhaustive coverage.

## Cost Controls

`x_search` is charged per server-side tool call, plus model tokens. Keep calls narrow by default.

**Pricing (as of June 2026):**

| Component | Rate |
|---|---|
| `x_search` tool invocation | $5.00 / 1,000 calls ($0.005 per call) |
| Token usage (input) | $1.25 / 1M tokens (grok-4.3 / grok-4.20) |
| Token usage (output) | $2.50 / 1M tokens (grok-4.3 / grok-4.20) |

**Live-tested cost benchmarks (grok-4.3, same query):**

| Mode | Typical Tokens | x_search Calls | Estimated Cost |
|---|---|---|---|
| cost-first + strict prompt | ~4,500–5,500 | 1 | ~$0.012–$0.015 |
| cost-first, no prompt constraint | ~7,000–8,000 | 2 | ~$0.020–$0.025 |
| quality-first (3 calls) | ~8,000–10,000 | 3 | ~$0.025–$0.035 |

At cost-first rates, **$5 supports roughly 330–400 searches**. The tool invocation fee ($0.005) is the dominant cost driver — each extra `x_search` call triggered by the model matters more than token volume.

- Public `max_tool_calls` may not fully prevent Grok from making multiple internal X searches. In cost-first mode, also instruct the model to use exactly one keyword/latest search and no semantic follow-up.
- Set `max_tool_calls` to `1` in cost-first mode.
- Use `max_tool_calls` between `3` and `6` in quality-first mode.
- Use `reasoning.effort: "low"` for lookup tasks.
- Set `max_output_tokens` between `500` and `900` for cost-first mode.
- Set `max_output_tokens` between `1200` and `2200` for quality-first mode.
- Add date bounds with `from_date` and `to_date` whenever possible.
- Ask for a small result count in the prompt, such as "Return up to 3 findings".
- Avoid broad prompts like "search everything" or "analyze all discussion".
- Use `allowed_x_handles` or `excluded_x_handles` to filter by user, but **never both at the same time** (returns HTTP 400).
- Use `enable_image_understanding: true` only if the user explicitly asks about images or visual content.

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

try {
  $response = Invoke-RestMethod `
    -Method Post `
    -Uri "https://api.x.ai/v1/responses" `
    -Headers $headers `
    -Body $payload `
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

# Defensive parse: response.output may be absent or not an array
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

## Python Call Example

For agents that write Python instead of PowerShell, use this self-contained pattern:

```python
import os, requests

api_key = os.environ.get("XAI_API_KEY")
if not api_key:
    raise ValueError("Set XAI_API_KEY before calling xAI X Search.")

payload = {
    "model": "grok-4.3",
    "input": [{
        "role": "user",
        "content": "Use X search in cost-first mode. Use exactly one X keyword/latest search query. Do not run semantic search, user search, thread fetch, or follow-up searches. Search for up to 3 recent X posts about: Grok API. Return author handle, date, summary, and URL."
    }],
    "tools": [{
        "type": "x_search",
        "from_date": "2026-06-01"
    }],
    "max_tool_calls": 1,
    "reasoning": {"effort": "low"},
    "max_output_tokens": 800
}

resp = requests.post(
    "https://api.x.ai/v1/responses",
    headers={"Authorization": f"Bearer {api_key}"},
    json=payload,
    timeout=120
)
resp.raise_for_status()
data = resp.json()

# Extract answer
answer = ""
for item in data.get("output", []):
    if item.get("type") == "message":
        for c in item.get("content", []):
            if c.get("text"): answer += c["text"] + "\n"

# Extract usage
usage = data.get("usage", {})
x_calls = usage.get("server_side_tool_usage_details", {}).get("x_search_calls", 0)

print(f"Answer:\n{answer}")
print(f"x_search_calls: {x_calls}")
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

- `400`: bad request — key may be invalid, malformed, or the endpoint rejected the payload. Check key format and request body.
- `401` or `403`: key is missing, invalid, revoked, or lacks permission.
- `429`: rate limit or quota issue.
- Connection failures (DNS, TLS, network): the `.ps1` script detects missing `Response` and reports a connection error; inline callers should wrap the HTTP call and handle exceptions where `Response` is null.
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
