# xAI X Search Skill

A Codex/Grok Skill for searching X/Twitter through the xAI Responses API `x_search` tool with conservative cost controls.

Use it when an agent needs to verify recent X posts, find discussion around a claim, or call Grok's X search capabilities from a reusable workflow.

## What It Does

- Uses the public xAI Responses API tool: `{ "type": "x_search" }`
- Documents the internal search tools Grok may invoke:
  - `x_keyword_search`
  - `x_semantic_search`
  - `x_user_search`
  - `x_thread_fetch`
- Defaults to low-cost behavior:
  - cost-first mode by default
  - `max_tool_calls: 1` plus a strict one-search prompt
  - `reasoning.effort: "low"`
  - bounded output tokens
  - date-filtered searches when possible
- Supports quality-first mode for broader semantic/user/thread search when recall matters more than cost.
- Keeps the main workflow self-contained in `SKILL.md`, because many agents only read that file.
- Includes a reusable PowerShell helper script for agents that can read bundled resources.

## Install

Import this repository as a Skill in Codex/Grok, or copy the repository folder into your local skills directory:

```powershell
# Codex
git clone https://github.com/Tan35/xai-x-search-skill.git "$env:USERPROFILE\.codex\skills\xai-x-search"

# Grok CLI
git clone https://github.com/Tan35/xai-x-search-skill.git "$env:USERPROFILE\.grok\skills\xai-x-search"
```

## Setup

Set your xAI API key as an environment variable. Do not hard-code it in the Skill or scripts.

```powershell
$env:XAI_API_KEY = "xai-..."
```

If you accidentally paste a real API key into chat, rotate or revoke it in the xAI console.

## Use From An Agent

Ask the agent:

```text
Use $xai-x-search to search X for recent posts about "Grok CLI X search tools" and return 3 concise findings with links.
```

## Modes

The Skill chooses a mode before making the API call:

- **Cost-first**: default. Best for quick checks and low spend. It asks Grok to use exactly one keyword/latest X search and avoids semantic, user, thread, and follow-up searches.
- **Quality-first**: best for deeper research. It allows semantic search, keyword search, and relevant user/thread context, but can trigger multiple billable X search calls.

Example prompts:

```text
Use $xai-x-search in cost-first mode to check whether people are discussing "Claude Mythos". Return 3 links.
```

```text
Use $xai-x-search in quality-first mode to investigate the "Claude Mythos" rumor across X, including threads and source confidence.
```

## Self-Contained Usage

The full API calling pattern is embedded directly in `SKILL.md`. This is intentional: many agents import a Skill from GitHub but only read `SKILL.md`, not files under `scripts/`.

Ask the agent:

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

The script returns JSON with:

- `mode`
- `answer`
- `x_search_calls`
- `total_tokens`
- `tool_calls`
- `max_tool_calls_limit`
- `actual_tool_calls`
- `warnings`

## Cost Notes

xAI charges two independent components per request: **token usage** and **tool invocation fees**.

> **Common misconception**: The billing unit for `x_search` is **not** the API request — it is the **internal tool invocation**. A single call to `POST /v1/responses` can trigger multiple internal X searches (e.g., `x_keyword_search` + `x_semantic_search`), and each one is billed separately at $0.005. Setting `max_tool_calls: 1` does not hard-limit this — it is advisory. This is why cost-first mode must combine the parameter with a strict prompt constraint.

### Pricing (as of June 2026)

| Component | Rate |
|---|---|
| `x_search` tool invocation | $5.00 / 1,000 calls ($0.005 per call) |
| Token input (grok-4.3 / grok-4.20) | $1.25 / 1M tokens |
| Token output (grok-4.3 / grok-4.20) | $2.50 / 1M tokens |
| Token input (grok-build-0.1) | $1.00 / 1M tokens |
| Token output (grok-build-0.1) | $2.00 / 1M tokens |

### Live-Tested Cost Benchmarks

The following numbers are based on real API calls with the same query (`xAI Grok API`) across models:

| Model | Tokens | x_search Calls | Est. Cost / Search |
|---|---|---|---|
| `grok-4.3` (cost-first + strict prompt) | ~4,500–5,500 | 1 | ~$0.012–$0.015 |
| `grok-4.20-non-reasoning` (fastest) | ~4,000–4,500 | 1 | ~$0.010–$0.012 |
| `grok-4.20-reasoning` | ~6,000–6,500 | 1 | ~$0.014–$0.016 |
| `grok-4.3` (quality-first, 3 calls) | ~8,000–10,000 | 3 | ~$0.025–$0.035 |
| `grok-4.3` (no prompt constraint) | ~7,000–8,000 | 2 | ~$0.020–$0.025 |

At cost-first rates with `grok-4.3`, **$5 supports roughly 330–400 searches**. The tool invocation fee ($0.005/call) is the dominant cost driver — each extra `x_search` call triggered by the model adds more to the bill than token volume differences between models.

### Tips to Keep Costs Low

- Use date ranges to narrow the search window.
- Ask for a small number of results (3–5).
- Keep `MaxToolCalls` at `1` and combine with a strict prompt to prevent extra calls.
- Prefer cost-first mode unless the user explicitly asks for completeness.
- Use concise output (`max_output_tokens` ≤ 900 in cost-first mode).

## Model Compatibility & Search Behavior

Based on live testing across different xAI models, here is how they handle the `x_search` tool:

- **`grok-4.3`**: The flagship model. Fully supports `reasoning.effort` and follows strict prompt constraints perfectly. Best choice for controlled searches.
- **`grok-4.20-0309-reasoning` / `grok-4.20-0309-non-reasoning`**: Supports `x_search`, but **does not support** the `reasoning.effort` parameter. Passing `reasoning: { effort: "low" }` will return an HTTP 400 error. If you use these models, you must remove the `reasoning` block from the payload.
- **`grok-build-0.1`**: As a coding-focused model, it surprisingly supports `x_search`. However, it lacks strong cost-control alignment and may trigger multiple internal searches (e.g., keyword + semantic + keyword) even for simple queries, consuming significantly more tokens. Not recommended for general search tasks.

When running identical keyword search prompts, all models successfully invoke `x_keyword_search` internally, but their output formatting styles vary slightly (e.g., bullet lists vs. numbered lists, inline markdown citations vs. raw URLs).

## Advanced Parameters & Behavior

Based on live testing, here is how advanced parameters behave:

- **`allowed_x_handles` & `excluded_x_handles`**: These work perfectly for filtering by user. However, you **cannot use both at the same time** (returns HTTP 400).
- **`enable_image_understanding`**: Setting this to `true` allows the model to process and describe images attached to tweets, but it consumes more tokens. Use only when visual context is explicitly requested.
- **Combined Tools**: `x_search` can be used alongside `web_search` in the same API call. The model will autonomously query both X and the broader web and synthesize the results.
- **Empty Results**: If the query is too narrow (e.g., extremely specific keyword + 1-day date range), the API gracefully returns no results without throwing an error.

## Known Limitations

### `max_tool_calls` Is Not Strictly Enforced

xAI's `max_tool_calls` parameter is advisory, not a hard limit. In testing, setting `max_tool_calls=1` produced 2-3 actual server-side search calls on some runs. The `.ps1` script includes a post-hoc check that warns when actual server calls exceed the limit (using `x_search_calls` from the usage block). Cost-first mode cannot rely on this parameter alone — combine it with prompt-level constraints.

### Error Code Behavior

Invalid or malformed API keys may return HTTP `400` (bad request), not `401` or `403`. The script handles all three codes plus connection failures (DNS, network, TLS) where no HTTP response exists.

### PowerShell Compatibility

The bundled helper script requires PowerShell. On Linux or macOS, install [PowerShell](https://github.com/PowerShell/PowerShell) first. The script avoids PS7+-only operators and uses `if/else` for PS5.1 compatibility. Agents that cannot run PowerShell should use the self-contained inline example in `SKILL.md`.

## Files

- `SKILL.md`: Skill instructions for agents.
- `agents/openai.yaml`: UI metadata for compatible agents.
- `scripts/xai_x_search.ps1`: Reusable PowerShell caller with error handling and cost warnings.
- `LICENSE`: MIT license.

## References

| Document | Description |
|---|---|
| [X Search Tool](https://docs.x.ai/developers/tools/x-search) | Official `x_search` parameter reference and SDK examples |
| [Tool Usage Details](https://docs.x.ai/developers/tools/tool-usage-details) | Billing unit clarification, `tool_calls` vs `server_side_tool_usage`, `max_turns` behavior |
| [Pricing](https://docs.x.ai/docs/pricing) | Tool invocation fees, token rates, Batch API discounts |
| [Models](https://docs.x.ai/docs/models) | Model catalog, context windows, per-model pricing |
| [Responses API](https://docs.x.ai/developers/responses-api) | Responses API overview and endpoint reference |
| [Web Search Tool](https://docs.x.ai/developers/tools/web-search) | `web_search` documentation (can be combined with `x_search`) |
