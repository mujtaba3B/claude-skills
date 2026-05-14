# claude-skills . Project Index

Content catalog. Companion to `LOG.md` (chronological/narrative). This file is the "where do I find X?" lookup; LOG.md is the "what happened and why?" history.

Per `CLAUDE.md`: keep this updated when artifacts are created, renamed, or deprecated. Do NOT catalog every file inside every skill (use `ls` for that). Only list things a future session would benefit from finding without hunting.

---

## Meta / project schema

| Path | What it is |
|---|---|
| `CLAUDE.md` | Project schema. Auto-loaded by Claude Code in any session under this tree. Defines repo layout, skill conventions, when to update LOG/INDEX. |
| `LOG.md` | Chronological decision log. |
| `INDEX.md` | This file. |
| `README.md` | Public-facing install + usage doc. The tagline list of skills lives here. |

## Install script

| Path | What it is |
|---|---|
| `install.sh` | Symlinks every top-level directory containing a `SKILL.md` into `~/.claude/skills/`. Idempotent: refreshes links and cleans stale ones. |

## Skills

| Path | What it does |
|---|---|
| `handoff-prompt/` | `/handoff-prompt` . Generates a self-contained handoff prompt that a fresh Claude Code session can pick up from. Snapshots task, decisions, file paths, conventions, open questions; copies to clipboard for Cmd+V into a new session. |

## External references

| Where | What it is |
|---|---|
| `https://github.com/mujtaba3B/claude-skills` | Public home for this repo. |
| `https://github.com/mujtaba3B/gstack-extensions` | Sibling repo for skills that layer on [gstack](https://github.com/garrytan/gstack) (`/pr-watcher`, `/qa-headless`, PM Penny, Feature Frank). |
| `~/.claude/skills/` | Flat namespace Claude Code scans at session start. `install.sh` symlinks into here. |
