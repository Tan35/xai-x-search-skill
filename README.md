# xAI X Search Skill

Cost-aware X search for Grok/Codex agents via the Responses API `x_search` tool.

- **Agents only need [`SKILL.md`](./SKILL.md)** (curl + JSON). No PowerShell required.
- **Demo:** [https://x-search.tanxy.club](https://x-search.tanxy.club) (your own key)

## Install

```bash
# Codex
git clone https://github.com/Tan35/xai-x-search-skill.git ~/.codex/skills/xai-x-search

# Grok CLI
git clone https://github.com/Tan35/xai-x-search-skill.git ~/.grok/skills/xai-x-search
```

Windows: use `$env:USERPROFILE\.codex\skills\xai-x-search` (or `.grok\...`) instead of `~/...`.

```bash
export XAI_API_KEY="xai-..."
```

## Modes

| Mode | Default? | Behavior |
|---|---|---|
| **cost-first** | yes | One keyword/latest search |
| **quality-first** | no | Semantic + keyword; threads/users if needed |

One HTTP request can still trigger **multiple** billable internal searches (~$0.005 each). Cost-first uses `max_tool_calls: 1` **and** a strict prompt. See `SKILL.md`.

## Layout

| Path | Who it’s for |
|---|---|
| `SKILL.md` | Agents (source of truth) |
| `scripts/*.ps1` | Optional local helper if you have PowerShell |
| `agents/openai.yaml` | UI metadata for some hosts |

## Docs

- [X Search](https://docs.x.ai/developers/tools/x-search)
- [Pricing](https://docs.x.ai/docs/pricing)
- [Tool usage](https://docs.x.ai/developers/tools/tool-usage-details)

MIT
