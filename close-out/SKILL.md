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

### Step 6: One-line summary

End with one or two lines like:

> Closed out. Updated LOG.md (3 entries across 2 repos), saved 1 memory, distilled 4 pending Q+A (2 approved). PR opened on public-claude-skills (link). CLAUDE / INDEX / README unchanged. No Pencil sweep.

Do not print a long recap; the user already saw the inventory and can read `git log`.

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
