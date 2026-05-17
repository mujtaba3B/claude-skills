---
name: distill-question-and-answer-log-to-principles
description: Review pending AskUserQuestion captures from the question-and-answer pending log and distill recurring patterns into question_and_answer_decision memory entries that future Claude Code sessions can rely on. Trigger when the user says "/distill-question-and-answer-log-to-principles", "distill the question and answer log", "distill the Q and A log", "process pending questions", "review pending memory", or whenever this skill is invoked as a step inside /close-out. Each pending entry is classified, presented as a diff, and only written after explicit user approval. Never auto-writes anything that contradicts a higher-tier source (CLAUDE.md or feedback memory).
---

# Distill question and answer log to principles

A PostToolUse hook (`~/.claude/scripts/question-and-answer-capture.sh`) records every `AskUserQuestion` answer as a JSON line in `~/.claude/projects/-Users-mujtaba-dev/memory/.question-and-answer-pending.jsonl`. That log is write-only. This skill turns those raw captures into durable `question_and_answer_decision_*.md` entries in the same memory dir, with the user reviewing every proposed write before it lands.

## Inputs

- **Pending log:** `~/.claude/projects/-Users-mujtaba-dev/memory/.question-and-answer-pending.jsonl`. Each line is one capture: `{ts, session_id, cwd, tool, question_payload, response, context, status}`.
- **Existing memory:** every `*.md` in `~/.claude/projects/-Users-mujtaba-dev/memory/`. Read them so reinforcement and contradiction detection works.
- **Higher-tier sources:** `~/.claude/CLAUDE.md` and `~/dev/CLAUDE.md`. These outrank memory; never auto-write a `question_and_answer_decision_*.md` that contradicts them.

## Conflict hierarchy (HARD RULE)

CLAUDE.md > feedback memory > question_and_answer_decision. If a proposed principle directly contradicts any text in `~/.claude/CLAUDE.md`, `~/dev/CLAUDE.md`, or any `feedback_*.md`, do NOT auto-write. Surface the conflict to the user with the new captured Q+A, the conflicting source path and quoted line, and three options:

1. Skip this Q+A (mark as rejected with reason "conflicts with higher tier").
2. Propose an edit to the existing higher-tier source.
3. Propose a narrower-scoped principle that avoids the conflict.

## How to run it

### Step 1: Load

Re-entrancy guard: if `Q_AND_A_HOOK_DISABLE=1` is set in the environment, exit with one line: "Distill skipped (re-entrancy guard active)." Do nothing else.

Otherwise read in one parallel bash batch:

- The full `.question-and-answer-pending.jsonl`.
- `MEMORY.md` and every `*.md` in the memory dir.
- `~/.claude/CLAUDE.md` and `~/dev/CLAUDE.md`.

Filter the JSONL to entries with `status == "pending"` only. If zero pending, end with: "No pending Q+A entries. Nothing to distill." Skip the rest.

### Step 2: Classify each pending entry

For each pending entry, decide one of:

| Classification | Meaning | Action |
|---|---|---|
| **new** | Recurring pattern or durable preference worth a fresh `question_and_answer_decision_*.md` | Propose a new file |
| **reinforces** | Confirms an existing memory entry (cite which) | Note in summary; offer to bump description if it has drifted |
| **contradicts-peer** | Directly contradicts another `question_and_answer_decision_*.md` | Surface conflict; user picks which wins |
| **conflict-higher-tier** | Contradicts CLAUDE.md or `feedback_*.md` | Apply HARD RULE above |
| **ignore** | One-off situational answer (e.g., "name this branch", "yes ship it"); no durable principle | Mark as rejected with reason "one-off" |

Use the captured `context` array (last ~6 transcript messages) plus the question and answer text. If context is empty or thin, the entry is more likely "ignore"; do not invent rationale.

### Step 3: Present proposals one at a time

For each non-ignored entry, render a proposal block:

```
Pending entry <N> of <total>  (ts: <ts>, session: <session_id_short>)

Question: <question text>
Options offered: <list>
User picked: <response>
Context excerpt: <one-line summary of the surrounding turn>

Classification: <new | reinforces | contradicts-peer | conflict-higher-tier>

Proposed file: question_and_answer_decision_<slug>.md
---
<full file content as it would be written>
---

MEMORY.md addition:
- [<Title>](question_and_answer_decision_<slug>.md) - <one-line description>
```

For `conflict-higher-tier`, also show the conflicting source path + the quoted contradicting line.

Then use `AskUserQuestion` with options: **Approve**, **Reject**, **Defer**, **Edit** (let me revise this proposal). Wait for the answer before moving to the next entry. The user's CLAUDE.md prefers one question at a time; respect that.

Auto-mark "ignore" entries as rejected silently without asking, but show a short list of them in the final summary so the user can object if any was misclassified.

### Step 4: Apply approved writes

For each approval, in one parallel batch:

- Write the new `question_and_answer_decision_<slug>.md` atomically: write to a tempfile in the same directory, then `mv` over the final path (rename is atomic on the same filesystem). Frontmatter matches existing memory convention:

```yaml
---
name: <kebab-slug>
description: <one-line summary used by Claude's loader>
type: question_and_answer_decision
originSessionId: <id from the capturing session>
---
```

Body:

```
<principle in one sentence>

**Why:** <rationale grounded in the user's answer and captured context>
**How to apply:** <when this kicks in for future sessions>
```

No "Rejected options" section. No reinforcement counter. No decay timestamp. No confidence tier. Keep it shaped like existing `feedback_*.md`.

- Append the index line to `MEMORY.md` atomically (read, append, temp-write, rename).

### Step 5: Update the JSONL

For each pending entry processed:

- **Approved:** flip its line to `status: "approved"` and add `approved_at: <iso-ts>`.
- **Rejected** (explicit or auto-"ignore"): flip to `status: "rejected"`, add `rejected_at: <iso-ts>`, add a short `rejected_reason` field ("one-off", "conflicts with higher tier", or whatever the user said).
- **Deferred:** leave `status: "pending"` unchanged.

Rewrite the entire JSONL atomically (read all lines, mutate the matching ones in memory, write to a tempfile, `mv`). Do not append-mutate; the file is small and a full rewrite is safer.

### Step 6: Purge old terminal entries

After the rewrite, purge any line with `status` in (`approved`, `rejected`) whose `approved_at`/`rejected_at` is more than 30 days before today. This keeps the log from growing forever while preserving recent rejections so they aren't re-proposed every session.

### Step 7: Summary

End with a short summary, format like `/close-out`'s final line:

> Distilled. Approved N, rejected M (k auto-ignored as one-offs), deferred D. Wrote N new memory entries. Pending remaining: D.

If conflicts were surfaced and unresolved, list them by ts so the user can revisit.

## Anti-patterns

1. **Batch-asking "approve all?".** One proposal per question, per the user's convention.
2. **Auto-writing a principle that contradicts CLAUDE.md or feedback memory.** Always surface; never assume the new capture is more correct.
3. **Inventing rationale.** If the captured context is thin, classify as "ignore" rather than guessing the user's reason.
4. **Calling `claude -p` from inside this skill.** This skill IS Claude reading the log. A subprocess would risk re-entrancy and add latency for no benefit.
5. **Per-line appends to a partially-updated JSONL.** Full rewrite under a tempfile + rename. The file is small.
6. **Preserving entries forever.** Old approved/rejected lines past 30 days are purged.
7. **Using em-dashes anywhere in proposals or summaries.** Per the user's global rule.
