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

- `answer`
- `x_search_calls`
- `total_tokens`
- `tool_calls`

## Cost Notes

xAI charges for server-side `x_search` tool calls in addition to model token usage. Keep searches narrow:

- Use date ranges.
- Ask for a small number of results.
- Keep `MaxToolCalls` at `1` unless you explicitly need a broader search.
- Prefer cost-first mode unless the user asks for completeness.
- Use concise output.

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
