# Question and answer memory loop: architecture

A capture-and-distill loop runs alongside the standard auto-memory system. Its job is to stop the same `AskUserQuestion` from being re-asked across sessions.

## How it works

1. A PostToolUse hook (`~/.claude/scripts/question-and-answer-capture.sh`) records every `AskUserQuestion` answer as a JSON line in `~/.claude/projects/-Users-mujtaba-dev/memory/.question-and-answer-pending.jsonl`.
2. The `/distill-question-and-answer-log-to-principles` skill processes that log on demand. It runs as Step 5 of `/close-out` and is also invocable directly.
3. Approved entries become `question_and_answer_decision_*.md` files in the memory dir, with the same frontmatter shape as `feedback_*.md`. Claude Code's existing relevance loader surfaces them in future sessions.

## Memory type: `question_and_answer_decision`

Frontmatter `type: question_and_answer_decision`. Body is principle + Why + How to apply. Same loader treatment as other memory types.

## Conflict hierarchy

`CLAUDE.md > feedback memory > question_and_answer_decision`.

The distiller never auto-writes a `question_and_answer_decision_*.md` that contradicts higher-tier text. Conflicts are surfaced and the user picks the resolution (skip, edit the higher tier, or narrow the new principle).

## Promotion is manual

When a `question_and_answer_decision_*.md` proves load-bearing, copy it by hand into `~/.claude/CLAUDE.md` or into a `feedback_*.md`. There is no automation for promotion.

## Re-entrancy guards (two layers)

1. *Subprocess guard:* both the capture hook and the distill skill no-op when `Q_AND_A_HOOK_DISABLE=1` is set, so a subprocess (e.g., a future `claude -p` invocation) does not feed the loop back into itself.
2. *In-process sentinel:* the distill skill's own approval `AskUserQuestion` calls use `header: "Distill"`, and the capture hook skips any AskUserQuestion carrying that reserved header. The env-var guard does not cover this case because the distill skill IS the parent Claude process asking the question; nothing spawns a subprocess for the env var to gate. The sentinel covers the in-process gap.

Both layers are required; one without the other leaves a real hole. Added 2026-05-17 after the in-process case actually fired during a `/close-out` run.

The `header: "Memory writes"` value (used by the memory write approval gate in `~/.claude/CLAUDE.md`) is similarly reserved and must be skipped by the capture hook for the same reason.
