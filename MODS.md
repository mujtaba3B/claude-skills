# MODS

Everything in this repo, at a glance. Two kinds:

- **Skill**: a slash command or agent persona Claude Code auto-loads. Installed as a symlink into `~/.claude/skills/`.
- **Harness**: a set of scripts and `~/.claude/settings.json` modifications that change how Claude Code itself behaves. Installed via its own `install.sh`.

| Name | Type | What it does | Install |
|------|------|--------------|---------|
| [agent-files-architect](skills/agent-files-architect/) | Skill | Audits and selectively improves `CLAUDE.md` / `AGENTS.md` / `LOG.md` / `INDEX.md` / `MEMORY.md`. Produces a precedence graph, stale-pointer scan, gap list. | `./install.sh skills` |
| [close-out](skills/close-out/) | Skill | End-of-session housekeeping. Walks project docs and persistent memory to apply this session's decisions and durable knowledge. | `./install.sh skills` |
| [distill-question-and-answer-log-to-principles](skills/distill-question-and-answer-log-to-principles/) | Skill | Reviews pending `AskUserQuestion` captures and distills recurring patterns into `question_and_answer_decision` memory entries. | `./install.sh skills` |
| [handoff](skills/handoff/) | Skill | Hands off the current work to a fresh Claude session (vertical iTerm2 split) or copies a self-contained handoff prompt to the clipboard. | `./install.sh skills` |
| [second-opinion](skills/second-opinion/) | Skill | Four modes: get a second opinion from Claude, Codex, Gemini, or a panel of all three in parallel. | `./install.sh skills` |
| [tab-state-indicator](harness/tab-state-indicator/) | Harness | Turns each Claude Code iTerm2 tab green when working and red when waiting on you. Plus a status-line summary of the last assistant message. | `cd harness/tab-state-indicator && ./install.sh` |

## Install one thing

Each row's `Install` column has the exact command. Run from the repo root unless noted.

## Install everything

```bash
./install.sh all
```

This runs every skill symlink and every harness `install.sh`. Each harness mod still asks for `y/N` confirmation per its own `install.sh` (pass `MUTWO_YES=1 ./install.sh all` to skip all confirmations).

## Install interactively

```bash
./install.sh
```

Picker prompt: skills only, harness only, everything, or individual mods.
