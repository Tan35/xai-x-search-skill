# xAI X Search Skill

A Codex/Grok skill for searching X/Twitter through the xAI Responses API `x_search` tool, with conservative cost controls.

Use it when an agent needs to check recent posts, find discussion around a claim, or call Grok’s X search from a reusable workflow.

**Live demo (bring your own key):** [https://x-search.tanxy.club](https://x-search.tanxy.club)

The demo mirrors cost-first / quality-first modes. Your API key stays in the browser (`localStorage`) and is only sent to the demo’s proxy for that request.

## What It Does

- Uses the public xAI Responses API tool: `{ "type": "x_search" }`
- Documents internal tools Grok may invoke:
  - `x_keyword_search`
  - `x_semantic_search`
  - `x_user_search`
  - `x_thread_fetch`
- Defaults to low-cost behavior:
  - cost-first mode by default
  - `max_tool_calls: 1` plus a strict one-search prompt
  - `reasoning.effort: "low"` when the model supports it
  - bounded output tokens
  - date filters when possible
- Supports quality-first mode for semantic/user/thread search when recall matters more than cost
- Keeps the main workflow in `SKILL.md` (many agents only load that file)
- Includes a PowerShell helper for agents that can run bundled scripts

## Install

Clone into your local skills directory:

```powershell
# Codex (Windows)
git clone https://github.com/Tan35/xai-x-search-skill.git "$env:USERPROFILE\.codex\skills\xai-x-search"

# Grok CLI (Windows)
git clone https://github.com/Tan35/xai-x-search-skill.git "$env:USERPROFILE\.grok\skills\xai-x-search"
```

```bash
# macOS / Linux
git clone https://github.com/Tan35/xai-x-search-skill.git ~/.codex/skills/xai-x-search
# or
git clone https://github.com/Tan35/xai-x-search-skill.git ~/.grok/skills/xai-x-search
```

## Setup

```powershell
$env:XAI_API_KEY = "xai-..."
```

```bash
export XAI_API_KEY="xai-..."
```

Do not hard-code the key. If you paste a real key into chat, rotate it in the [xAI console](https://console.x.ai).

## Use From An Agent

```text
Use $xai-x-search to search X for recent posts about "Grok CLI X search tools" and return 3 concise findings with links.
```

## Modes

- **Cost-first** (default): one keyword/latest search; avoids semantic, user, thread, and follow-ups unless the user pasted a status URL. Good for a quick check.
- **Quality-first**: semantic + keyword, optional user/thread context. Higher recall, more billable `x_search` calls.

```text
Use $xai-x-search in cost-first mode to check whether people are discussing "Claude Mythos". Return 3 links.
```

```text
Use $xai-x-search in quality-first mode to investigate the "Claude Mythos" rumor across X, including threads and source confidence.
```

## Self-Contained Usage

The full API pattern lives in `SKILL.md` on purpose: many agents import a skill from GitHub and only read that file.

```text
Use $xai-x-search to run a one-call X search for recent posts about "Grok CLI X search tools". Use the self-contained PowerShell/API example in SKILL.md, not bundled scripts.
```

## Use The Script Directly

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\xai-x-search\scripts\xai_x_search.ps1" `
  -Query "Grok CLI X search tools" `
  -Mode cost `
  -FromDate "2026-06-01" `
  -ToDate "2026-06-05" `
  -MaxToolCalls 1 `
  -MaxResults 3
```

Returns JSON including: `mode`, `answer`, `x_search_calls`, `total_tokens`, `tool_calls`, `max_tool_calls_limit`, `actual_tool_calls`, `warnings`.

## Cost Notes

xAI bills **token usage** and **server-side tool invocations** separately.

> **Common misconception:** The unit for `x_search` is **not** one HTTP request. One `POST /v1/responses` can run several internal X searches (`x_keyword_search`, `x_semantic_search`, …). Each successful call is billed (list price **$0.005**). `max_tool_calls: 1` is advisory — cost-first mode also needs a strict prompt.

### Pricing (check docs; rates change)

| Component | Rate (list) |
|---|---|
| `x_search` | $5.00 / 1,000 calls ($0.005 each) |
| Token input (`grok-4.3` / `grok-4.20`) | $1.25 / 1M |
| Token output (`grok-4.3` / `grok-4.20`) | $2.50 / 1M |
| Token input / output (`grok-4.5`) | $2.00 / $6.00 per 1M |
| Token input / output (`grok-build-0.1`) | $1.00 / $2.00 per 1M |

Source of truth: [xAI pricing](https://docs.x.ai/docs/pricing).

### Live-tested benchmarks (illustrative)

Same query (`xAI Grok API`), approximate:

| Setup | Tokens | x_search | Est. cost |
|---|---|---|---|
| `grok-4.3` cost-first + strict prompt | ~4.5k–5.5k | 1 | ~$0.012–$0.015 |
| `grok-4.20` non-reasoning, cost-first | ~4k–4.5k | 1 | ~$0.010–$0.012 |
| `grok-4.3` quality-first (~3 calls) | ~8k–10k | 3 | ~$0.025–$0.035 |
| `grok-4.3` loose prompt | ~7k–8k | 2 | ~$0.020–$0.025 |

At cost-first rates with `grok-4.3`, **~$5 is on the order of a few hundred lookups**. Extra tool calls usually dominate small token differences between models.

### Tips

- Prefer date ranges
- Ask for few results (3–5)
- Keep `MaxToolCalls` at `1` **and** a strict one-search prompt
- Default to cost-first unless the user wants depth
- Cap `max_output_tokens` (e.g. ≤ 900 in cost-first)

## Model Compatibility

- **`grok-4.3`**: Default for this skill. Handles cost prompts well; supports `reasoning.effort`.
- **`grok-4.5`**: Stronger, higher token price. Fine if the user asks; overkill for simple link checks.
- **`grok-4.20-*`**: Supports `x_search`. **Do not** send `reasoning: { effort: ... }` (HTTP 400). Strip that block.
- **`grok-build-0.1`**: Can call `x_search` but often over-searches. Not recommended for general search.

## Advanced Parameters

- **`allowed_x_handles` / `excluded_x_handles`**: max 20 each; **not both at once** (HTTP 400)
- **`from_date` / `to_date`**: `YYYY-MM-DD`
- **`enable_image_understanding`**: only if the user cares about images (more tokens)
- **`enable_video_understanding`**: X-only; only if the user cares about video
- **`x_search` + `web_search`**: allowed in one request; the model may hit both
- Narrow queries can return empty results without throwing

## Known Limitations

### `max_tool_calls` is advisory

Setting `1` can still yield multiple server-side X searches. The `.ps1` script warns when `x_search_calls` exceeds the limit. Always pair with prompt constraints.

### Errors

Invalid keys may return **400** as well as 401/403. The script also handles connection failures with no HTTP response.

### PowerShell

Bundled helper needs PowerShell (install on Linux/macOS if needed). Prefer the inline example in `SKILL.md` when the agent cannot run scripts.

## Files

| File | Role |
|---|---|
| `SKILL.md` | Instructions for agents |
| `agents/openai.yaml` | UI metadata for compatible agents |
| `scripts/xai_x_search.ps1` | CLI helper + cost warnings |
| `LICENSE` | MIT |

## References

| Document | Description |
|---|---|
| [X Search](https://docs.x.ai/developers/tools/x-search) | Tool parameters and SDK examples |
| [Tool usage details](https://docs.x.ai/developers/tools/tool-usage-details) | Billing unit, usage fields, turns |
| [Pricing](https://docs.x.ai/docs/pricing) | Tool + token rates |
| [Models](https://docs.x.ai/developers/models) | Catalog and per-model pricing |
| [Responses API (generate text)](https://docs.x.ai/developers/model-capabilities/text/generate-text) | Responses endpoint overview |
| [Web Search](https://docs.x.ai/developers/tools/web-search) | Can be combined with `x_search` |
