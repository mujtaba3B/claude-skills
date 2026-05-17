---
name: close-out
description: End-of-session housekeeping for the user's personal project-keeping convention. Walks the project's CLAUDE.md / LOG.md / INDEX.md / README.md / persistent memory and applies the entries that capture this session's decisions, gotchas, new artifacts, and new durable knowledge. Also handles the post-deploy Pencil `🚧 NEW NEW` mockup demotion sweep when applicable. Trigger when the user says any variant of "/close-out", "close out", "close this out", "let's wrap up", "wrap this up", "before we stop", "before we close up", "what needs documenting", "document what we did", "let's document", or "end the session", or otherwise signals they are stopping work on the current task and want their internal docs and memory brought up to date. This is DIFFERENT from /document-release and /end-sprint: do NOT trigger this skill for "update the changelog", "bump the version", "post-ship docs", "ship and document", or release-facing documentation. This skill is purely about the user's internal convention defined in ~/dev/CLAUDE.md and ~/.claude/CLAUDE.md.
---

# Close out

End-of-session housekeeping. The user's convention (per `~/dev/CLAUDE.md` and `~/.claude/CLAUDE.md`):

- `CLAUDE.md` per repo - project schema and conventions
- `LOG.md` per repo - chronological decision log, date-headed `## YYYY-MM-DD`, entries tagged `### [<feature>][<subtopic>] <title>`
- `INDEX.md` per repo - content catalog: where artifacts live
- `README.md` per repo - human-facing notes
- `~/.claude/projects/<project>/memory/` - durable cross-session knowledge (user / feedback / project / reference types)
- `.pen` wireframes (Pencil): demote `🚧 NEW NEW` frames whose content shipped

The convention only pays off if the files stay current. This skill is the discipline that prevents rot.

## How to run it

**Default mode is fast and parallel. Apply first, summarize at the end.** Do NOT preview each drafted entry and ask for approval. The user explicitly chose speed over per-entry review (see the `close-out-no-preview` feedback memory). The summary is where the user reviews; if they want changes, iterate then.

### Step 0: Print the run roadmap

Before doing anything else, print the fixed roadmap (6 main steps plus a conditional 5.5) so the user can follow the run. Mark each step with a status indicator that updates as work progresses:

- `⏳` pending
- `🔄` in-progress
- `✅` done
- `⏭️` skipped (with reason inline)

Initial print:

```
Close-out plan:
- ⏳ 1. Inventory (git, memory dir, Q+A log, branch protection)
- ⏳ 2. Decide and apply edits (LOG / INDEX / CLAUDE / memory / README)
- ⏳ 3. Push and PR (direct push or open PR depending on branch protection)
- ⏳ 4. Pencil sweep (only if .pen was edited and a deploy happened)
- ⏳ 5. Distill Q+A pending log (only if pending entries exist)
- ⏳ 5.5. Agent files architect (only if TTL/session/activity trigger fires)
- ⏳ 5.7. Cleanup stale branches and return to main (per touched repo)
- ⏳ 6. Summary
```

As each step completes, print a one-liner like `✅ Step N done. <one-line outcome>` and continue. Do not reprint the full roadmap between every step; the running output reconstructs progress.

When a conditional step (4 or 5) is going to skip, mark it as `⏭️` with the reason at the moment you confirm the skip (during or right after Step 1), not later. Example: after inventory, if there were no `.pen` edits this session, immediately note `⏭️ Step 4 skipped: no .pen edits`.

For Step 6, reprint the full roadmap with final markers so the run ends with a clear "here is everything that happened" view, then add the one-line summary.

This roadmap is the user's read on what is about to happen and what is in flight. Keep it accurate and lightweight; do not embellish it with sub-bullets or commentary.

---

### Step 1: Inventory in one parallel bash call

Run a single bash invocation that gets everything you need:

- `git status` and `git log --oneline -20` for each touched repo (chain with `cd ... && ... ; cd ... && ...`)
- `ls` of `~/.claude/projects/<project>/memory/` to see existing memory files
- `ls` of `~/.cloudflare/`, any new credential dirs, etc.

Also re-scan the conversation for: decisions made in chat, gotchas that cost time, deploys/state changes in external systems (GitHub repos, CF projects, DNS zones), `.pen` file edits.

Surface a short inventory to the user (5-10 bullets max). Do not ask any question yet; just show what you saw, then immediately move to Step 2.

### Step 2: Decide and apply in one batch

Use these rules to decide what gets written where:

| What | Where |
|------|-------|
| WHY a decision was made | `LOG.md` in the affected repo |
| Gotcha that cost real time (with symptom + fix so future-you can grep) | `LOG.md` |
| Where a new artifact lives | `INDEX.md` |
| Durable convention that governs future work IN THIS PROJECT | `CLAUDE.md` |
| Durable convention that governs future work ACROSS PROJECTS | memory (feedback type) |
| Fact about external infrastructure | memory (reference type), maybe also `INDEX.md` / `CLAUDE.md` |
| User role / preference revealed in chat | memory (user type) |
| User-visible surface or setup steps changed | `README.md` |

For LOG entries: match the existing file's voice (terse vs. discursive) and tag conventions. Date header `## YYYY-MM-DD` once per day, not per entry. Lead with the decision or fact, then a short paragraph of WHY (motivation, constraint, the gotcha + fix).

For memory: read `MEMORY.md` first to avoid duplicates. Prefer updating an existing memory file over creating a new one.

**Apply all edits in parallel tool calls.** Read all the files you need to edit in one parallel batch; apply all the Edits in a follow-up parallel batch. Do not Read-then-Edit-then-Read-then-Edit serially across repos.

**Do not preview entries.** Do not generate "here's what I'm about to add, look right?" tables. Just apply. If something needs revision, the user will say so after the summary.

### Step 3: Push and PR

For each repo that got edits:

- If `main` is not branch-protected: commit and push directly.
- If `main` IS branch-protected: create a branch (`close-out/<date>`), push, open a PR via `gh pr create`, and surface the PR URL in the summary. Don't auto-merge unless the user has previously said to.

Check branch protection in your inventory step so you know which path each repo needs.

### Step 4: Pencil demotion (only if applicable)

Skip entirely if no `.pen` files were touched this session OR no deploy happened.

If both apply: use `mcp__pencil__get_editor_state` to find `🚧 NEW NEW ` frames in each touched `.pen`, cross-reference what actually shipped (use the diff / commits / LOG entry you just wrote), and apply demotions (remove prefix, remove orange dashed stroke) for the frames whose content is in production. Demotions are reversible, so apply directly. Add a brief note under the relevant `[<feature>][spec]` LOG tag so the wireframe state stays auditable.

### Step 5: Distill the question-and-answer pending log

The `AskUserQuestion` capture hook (`~/.claude/scripts/question-and-answer-capture.sh`) appends raw Q+A captures to `~/.claude/projects/-Users-mujtaba-dev/memory/.question-and-answer-pending.jsonl`. Close-out is the natural point to process them.

- Count `status: "pending"` lines in that JSONL.
- If zero: skip this step silently. No mention in the summary.
- If non-zero: invoke `/distill-question-and-answer-log-to-principles`. The skill walks each pending entry, surfaces proposals one at a time, and writes only what the user approves. It also handles the conflict hierarchy (CLAUDE.md beats feedback memory beats question_and_answer_decision).

Do not try to distill inline here; the dedicated skill knows the contract.

### Step 5.5: Agent files architect (conditional)

Invoke `/agent-files-architect --close-out`. The `--close-out` flag bypasses the manual mode menu and tells the skill to run silently. The skill then runs its own trigger gate (7 days since last run, 10 sessions since last run, or 3 agent files touched this session) and no-ops if nothing fires. Close-out passes the third signal through the `AGENT_FILES_TOUCHED_THIS_SESSION` env var, counted from Step 1 inventory (any session-touched file matching `CLAUDE.md`, `AGENTS.md`, `LOG.md`, `INDEX.md`, `MEMORY.md`, or a `.md` referenced from a CLAUDE.md in the up-walk).

When fired, the architect runs up-walk only (no `--deep`, `--research`, or `--review`), targets a whole-run budget under 2 seconds, and applies the single approval gate inline. If the user declines the bundle, the report is saved and close-out continues to Step 6. If no trigger fires, mark this step `⏭️` with reason "no trigger" and move on.

Do not duplicate the gate logic here; the architect owns it.

### Step 5.7: Cleanup stale branches and return to main

For each repo touched in this session (plus the cwd repo), run:

```bash
~/.claude/skills/close-out/cleanup-branches.sh <repo-path>
```

What it does (read the script for the authoritative behavior):

- `git fetch --prune origin` so "merged into origin/main" reflects what GitHub actually has.
- Lists local branches reachable from `origin/<base>` (base auto-detected via `origin/HEAD`, fallback `main` then `master`).
- If the current branch is among them, switches to base first (and `git pull --ff-only`).
- Deletes each merged branch with `git branch -D` (safe because merged-into-base was already verified).
- Skips the current branch when the working tree is dirty or has unpushed commits; cleans the rest.
- Never pushes branch deletions to a remote. PR auto-delete on GitHub handles that side.
- Honors `PROTECT_BRANCHES=a,b` env var for extra never-delete branches.
- `CLEANUP_DRY_RUN=1` previews without changing anything.

Run it per touched repo. Surface counts in the summary (e.g., "cleaned 3 branches in mutwo, 0 in user_growth"). If the script prints `KEPT-current ...`, mention which branch and why so the user knows to commit/push before next close-out.

Tests for this helper live in `~/.claude/skills/close-out/test_cleanup_branches.sh`. Run them when modifying the helper.

### Step 6: One-line summary

Reprint the full roadmap with final markers, then end with one or two lines like:

> Closed out. Updated LOG.md (3 entries across 2 repos), saved 1 memory, distilled 4 pending Q+A (2 approved). PR opened on public-claude-skills (link). CLAUDE / INDEX / README unchanged. No Pencil sweep.

Final roadmap reprint should look like:

```
Close-out plan:
- ✅ 1. Inventory (3 repos, 4 touched files, no Q+A pending)
- ✅ 2. Decide and apply edits (LOG x3, memory x1)
- ✅ 3. Push and PR (PR #4 opened on public-claude-skills)
- ⏭️ 4. Pencil sweep (no .pen edits this session)
- ⏭️ 5. Distill Q+A (no pending entries)
- ⏭️ 5.5. Agent files architect (no trigger)
- ✅ 5.7. Cleanup stale branches (deleted 2 in mutwo, 0 elsewhere; now on main)
- ✅ 6. Summary
```

Do not print a long recap beyond this; the user saw the inventory and can read `git log`.

## When to actually ask a question

Only when a decision is genuinely ambiguous, not for routine apply-this confirmation. Genuinely ambiguous cases include:

- A LOG entry could plausibly go in 2 different repos and you can't decide.
- A new convention is borderline (could be `CLAUDE.md` OR could just be a one-off LOG entry).
- A gotcha is on the line between "worth documenting" and "too narrow to bother".

If you find yourself drafting a question that starts with "want me to" or "apply this entry?", that's the antipattern this skill was tuned against. Just apply.

When you do ask a genuinely ambiguous question, wrap it in the user's prominent question format and make it the last thing in the response:

```
---

### ❓ QUESTION

> The actual question.

---
```

No em-dashes anywhere in the skill's output. Use periods, colons, semicolons, parentheses, or hyphens.

## Anti-patterns

1. **Sequential tool calls when parallel would work.** Reading 5 files? One parallel batch. Editing 4 files? One parallel batch. Do not interleave.
2. **Re-reading a file you just edited to "verify".** Edit / Write would have errored if it failed; the harness tracks state for you.
3. **Per-entry preview tables.** The user said no.
4. **Updating `CLAUDE.md` for single-use decisions.** That belongs in `LOG.md`.
5. **Creating new memory entries that duplicate existing ones.** Read `MEMORY.md` first.
6. **Pushing directly to a branch-protected `main`.** Check branch protection during inventory; open a PR for protected repos.
7. **Demoting Pencil frames without verifying what shipped.** Removing the `🚧` marker on something that didn't actually ship is worse than leaving it marked.
8. **Apologizing or narrating what you're about to do.** Show inventory, apply, summarize.
9. **LOG entries that just restate `git log`.** The entry should be "Picked X over Y because of constraint Z" or "Hit gotcha A; root cause B; fix C". WHY, not WHAT.
