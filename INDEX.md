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
| `close-out/` | `/close-out` . End-of-session housekeeping for the CLAUDE.md / LOG.md / INDEX.md / README.md / memory convention. Surveys what happened in the session, drafts entries one phase at a time, applies after approval. Also runs the Pencil `🚧 NEW NEW` mockup demotion sweep when applicable. |
| `second-opinion/` | `/second-opinion` . Get a second opinion from another LLM. Four modes: `claude` (single subagent), `codex` (OpenAI), `gemini`, or `panel` (all three in parallel). Infers expert persona from context, composes one self-contained prompt, dispatches by mode, saves full opinion(s) to `/tmp/second-opinion-<mode>-<ts>/`, returns a concise synthesis. Panel mode includes a required Steelman section when all three converge. |
| `distill-question-and-answer-log-to-principles/` | `/distill-question-and-answer-log-to-principles` . Processes the `AskUserQuestion` capture log (`~/.claude/projects/-Users-mujtaba-dev/memory/.question-and-answer-pending.jsonl`), classifies each pending Q+A, surfaces proposals one at a time, and writes approved entries as new `question_and_answer_decision_*.md` files in the memory dir. Runs as Step 5 inside `/close-out` and is also invocable standalone. Companion to the capture hook at `~/.claude/scripts/question-and-answer-capture.sh`. |

## External references

| Where | What it is |
|---|---|
| `https://github.com/mujtaba3B/claude-skills` | Public home for this repo. |
| `https://github.com/mujtaba3B/gstack-extensions` | Sibling repo for skills that layer on [gstack](https://github.com/garrytan/gstack) (`/pr-watcher`, `/qa-headless`, PM Penny, Feature Frank). |
| `~/.claude/skills/` | Flat namespace Claude Code scans at session start. `install.sh` symlinks into here. |
