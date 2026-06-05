---
name: xai-x-search
description: Use this skill when an agent needs to search X/Twitter through the xAI Responses API x_search tool, verify current X posts, fetch recent discussion, compare claims on X, or use Grok's internal X search capabilities such as x_keyword_search, x_semantic_search, x_user_search, and x_thread_fetch. It includes cost controls and a reusable PowerShell script.
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

## Quick PowerShell Use

Use the bundled script for low-cost searches:

```powershell
$env:XAI_API_KEY = "xai-..."
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\xai-x-search\scripts\xai_x_search.ps1" `
  -Query "Grok CLI X search tools" `
  -FromDate "2026-06-01" `
  -ToDate "2026-06-05" `
  -MaxToolCalls 1 `
  -MaxResults 3
```

For Grok CLI agents, the same script is also available at:

```powershell
$env:USERPROFILE\.grok\skills\xai-x-search\scripts\xai_x_search.ps1
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
