---
name: xai-x-search
description: Search X/Twitter via xAI Responses API x_search with cost-first (default) or quality-first modes. Use for recent posts, claim checks, and discussion lookup. Prefer one billable search unless the user wants depth.
---

# xAI X Search

Public tool only:

```json
{ "type": "x_search" }
```

Internally Grok may run `x_keyword_search`, `x_semantic_search`, `x_user_search`, `x_thread_fetch`. Agents never call those by name.

**This file is the whole skill.** Do not require `scripts/`. Prefer `curl` or any HTTP client. Key: env `XAI_API_KEY` — never hard-code or echo it.

## Modes

| | Cost-first (default) | Quality-first |
|---|---|---|
| When | quick check, cheap, no preference | deep search, threads, “find everything” |
| `max_tool_calls` | `1` | `3`–`5` |
| `max_output_tokens` | `800` | `1800` |
| Search | one keyword/latest only | semantic + keyword; user/thread if needed |

Always say which mode you used if you defaulted to cost-first.

## Cost (the only gotcha that matters)

Billable unit = **successful internal `x_search` call** (~$0.005 list), **not** one HTTP request.

One Responses call can fire several searches. `max_tool_calls` is **advisory** — also put a hard limit in the prompt.

Tokens: `grok-4.3` / `4.20` ≈ $1.25 / $2.50 per 1M; `grok-4.5` ≈ $2 / $6. Check [pricing](https://docs.x.ai/docs/pricing).

**Default model:** `grok-4.3`.  
**4.20:** omit `reasoning`. **build:** avoid for search. **4.5:** only if user asks (pricier).

Optional tool fields: `from_date` / `to_date` (`YYYY-MM-DD`); `allowed_x_handles` **or** `excluded_x_handles` (not both); image/video understanding only if user cares about media.

## How to call (curl)

Cost-first — works on macOS / Linux / Windows if `curl` exists:

```bash
export XAI_API_KEY="xai-..."

curl -sS https://api.x.ai/v1/responses \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "grok-4.3",
    "input": [{
      "role": "user",
      "content": "Use X search in cost-first mode. Use exactly one X keyword/latest search. No semantic, user, thread, or follow-up searches unless a status URL was given. Search for up to 3 posts about: TOPIC. Return handle, date, one-line summary, URL. Mark strong match vs loose match (topic relevance only)."
    }],
    "tools": [{
      "type": "x_search",
      "from_date": "YYYY-MM-DD",
      "to_date": "YYYY-MM-DD"
    }],
    "max_tool_calls": 1,
    "reasoning": { "effort": "low" },
    "max_output_tokens": 800
  }'
```

Quality-first: same URL; set `max_tool_calls` to `5`, `max_output_tokens` to `1800`, and change the user content to allow semantic + keyword + thread/user when useful (up to 8 posts; strong vs loose match).

Drop the `reasoning` object for `grok-4.20*`.

## Response

- Text: `output[]` where `type == "message"`
- Billable searches: `usage.server_side_tool_usage_details.x_search_calls`
- Report that count if it exceeds the intended budget

## Failures

| Code | Meaning |
|---|---|
| 400 | Bad body or key; or `reasoning` on an unsupported model |
| 401 / 403 | Bad / missing key |
| 429 | Rate limit |
| empty hits | One simpler keyword retry, same `max_tool_calls` |

## Optional script

`scripts/xai_x_search.ps1` is for humans on Windows/PowerShell only. **Agents: ignore it** unless you can read and run that path. Use curl/JSON above instead.
