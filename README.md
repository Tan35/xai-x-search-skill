# xAI X Search Skill

Cost-aware X search for Grok/Codex agents via the Responses API `x_search` tool.

- **Agents only need [`SKILL.md`](./SKILL.md)** (curl + JSON). No PowerShell required.
- **Demo:** [https://x-search.tanxy.club](https://x-search.tanxy.club) (your own key)

## Install

Any agent that can load a skill from a folder only needs this repo (especially `SKILL.md`). Clone it somewhere your agent reads skills from:

```bash
git clone https://github.com/Tan35/xai-x-search-skill.git
# then point your agent at that directory, or copy/symlink into its skills path
```

Examples for hosts that use a default skills directory:

```bash
# Codex
git clone https://github.com/Tan35/xai-x-search-skill.git ~/.codex/skills/xai-x-search

# Grok CLI
git clone https://github.com/Tan35/xai-x-search-skill.git ~/.grok/skills/xai-x-search
```

Windows: swap `~/` for `$env:USERPROFILE\` (e.g. `$env:USERPROFILE\.codex\skills\xai-x-search`).

Other tools (Cursor, Claude Code, custom runners, etc.): use whatever path they document for skills/plugins — the skill itself is just files; **`SKILL.md` is the entrypoint**.

```bash
export XAI_API_KEY="xai-..."
```

## Modes

| Mode | Default? | Behavior |
|---|---|---|
| **cost-first** | yes | One keyword/latest search |
| **quality-first** | no | Semantic + keyword; threads/users if needed |

One HTTP request can still trigger **multiple** billable internal searches (~$0.005 each). Cost-first uses `max_tool_calls: 1` **and** a strict prompt. See `SKILL.md`.

## What does one search cost?

Rough numbers from live runs on **`grok-4.3`** (list prices: ~$0.005 per successful `x_search` + token fees). Not a quote — your query, model, and how free the agent is will move this.

| Setup | Typical x_search calls | Ballpark / request |
|---|---:|---|
| **This skill · cost-first** | 1 | **~$0.01–0.015** |
| **This skill · quality-first** | ~3 | **~$0.025–0.035** |
| **No skill** (agent free to multi-search) | often 2–4+ | **~$0.02–0.05+** |

Without the skill, a vague “search X for me” often turns into keyword + semantic (+ maybe a thread). Same HTTP call, **extra billable searches**. Cost-first is mainly about **stopping that by default**.

Order of magnitude: at cost-first rates, **~$5 ≈ a few hundred** one-shot lookups. Quality-first or loose agents burn that faster.

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
