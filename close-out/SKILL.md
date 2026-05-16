---
name: close-out
description: End-of-session housekeeping for the user's personal project-keeping convention. Walks the project's three schema files (CLAUDE.md, LOG.md, INDEX.md) plus README and persistent memory, decides what needs updating based on what happened in the session, and applies the edits. Also handles the post-deploy Pencil wireframe demotion sweep when applicable. Trigger when the user says any variant of "/close-out", "close out", "close this out", "let's wrap up", "wrap this up", "before we stop", "before we close up", "what needs documenting", "document what we did", "let's document", "end the session", or otherwise signals they are stopping work on the current task and want their internal docs and memory brought up to date. This is DIFFERENT from /document-release and /end-sprint: do NOT trigger this skill for "update the changelog", "bump the version", "post-ship docs", "ship and document", or release-facing documentation. This skill is purely about the user's internal LOG.md / INDEX.md / CLAUDE.md / memory convention defined in their ~/dev/CLAUDE.md and ~/.claude/CLAUDE.md.
---

# Close out

A working session is over (or being paused). The user wants their durable docs and memory to reflect what just happened so that future sessions, future-them, or another collaborator can pick up cleanly.

This skill is NOT about public release docs (that's `/document-release`). It is about the user's personal convention:

- `CLAUDE.md` (project schema, conventions, when to update LOG/INDEX)
- `LOG.md` (chronological decision log, date-headed `## YYYY-MM-DD`, entries tagged like `[topic][subtopic]`)
- `INDEX.md` (content catalog: where artifacts live)
- `README.md` (human-facing notes)
- `~/.claude/projects/<project>/memory/` (durable cross-session knowledge: user/feedback/project/reference types)
- `.pen` wireframes (Pencil): demote `🚧 NEW NEW` frames whose content shipped

## Why this skill exists

The user has invested in a convention where every `~/dev/` repo carries CLAUDE.md / LOG.md / INDEX.md so any future session (human or agent) can orient quickly. The convention only pays off if the files stay current. After a substantive session, things rot fast: decisions made in chat never make it to LOG.md, new files get added without an INDEX.md entry, new infra gets stood up without a memory note. This skill is the discipline that prevents that rot.

## How to work through it

Work through these phases in order. Do NOT batch the questions; ask them one at a time, wait for the answer, then move on. Each question MUST be wrapped in the user's prominent question format:

```
---

### ❓ QUESTION

> The actual question goes here, in a blockquote, on its own line.

---
```

Never trail explanation after the question. Never bury a question inline in prose. The question must be the LAST thing in the response.

No em-dashes. Anywhere. Use periods, colons, semicolons, parentheses, or hyphens.

### Phase 1: Inventory (no questions yet, just gather)

Before asking anything, build a quiet mental picture of the session. Use the available tools to surface what actually happened:

1. **Git activity** (in the current project repo, if applicable):
   - `git status` to see uncommitted changes.
   - `git log --oneline -20` to see what was committed in the session.
   - `git diff --stat <session-start-sha>..HEAD` if you can identify the start point, or just the last N commits to get a feel for scope.

2. **File-system changes outside the project**: scan the conversation for any files created or edited at paths OTHER than the current project. New CLI scripts, new repos (e.g. `~/dev/<name>/`), credential files (e.g. `~/.cloudflare/env`), new memory entries.

3. **Decisions made in chat that aren't in code**: re-read the conversation for moments where the user picked an option, ruled something out, established a preference, or hit a gotcha that took time to debug. These are LOG-worthy even if they left no code trace.

4. **Deploys / state changes in external systems**: anything that pushed to prod, created a service (GitHub repo, Cloudflare project, DNS zone, etc.), changed a config that lives outside the repo.

5. **Pencil files**: if any `.pen` file was edited via the Pencil MCP this session AND a deploy happened, the `🚧 NEW NEW` sweep applies. (If no `.pen` activity, skip the Pencil phase entirely.)

Surface a brief inventory to the user in 5-10 bullets before any questions. Format: "Here's what I saw this session. Want me to walk through what needs documenting?" Then proceed to Phase 2.

### Phase 2: LOG.md (one or more entries, almost always needed)

LOG.md is the most important file for this skill. Decisions, gotchas, direction changes, and non-obvious tradeoffs that happened in chat belong here, because they are NOT recoverable from `git log` (commit messages summarize the WHAT, LOG.md captures the WHY).

For each candidate entry you identified in Phase 1:

1. Draft the entry in the project's existing LOG.md voice and format. Check the existing entries first for tone (terse vs. discursive) and tagging conventions.
2. Use the date format `## YYYY-MM-DD` for the day header (one per day, not per entry). Add the date header only if today's date isn't already in the file.
3. Tag each entry like `### [<feature>][<subtopic>] <short title>`. Match the project's existing tag conventions.
4. Lead with the decision or fact. Then a short paragraph (or two) of WHY: the motivation, the constraint, the gotcha. Include enough detail that a future reader can judge whether the decision still applies.
5. For gotchas that cost real time, include the symptom and the fix, so future-you can grep for it.

Show the drafted entries to the user before applying. Ask one question:

> I want to add the following entries to LOG.md: [list of titles]. Look right, or want to drop / merge / rephrase any?

After the user approves, apply with the Edit tool (preserving any existing content). Re-read LOG.md right before editing in case it changed (the user may have edited concurrently).

### Phase 3: INDEX.md (only if new artifacts were added)

INDEX.md catalogs WHERE things live. It needs an update when:

- A new file was added that future sessions would benefit from finding (code, doc, asset, config).
- A new external reference was used or pinned (a dashboard URL, an external repo, a service that's now in the loop).
- A new related repo or sibling project was created.

It does NOT need an update for:

- Trivial code edits to existing files.
- Internal refactors that don't change the file layout.
- One-off experiments that won't be revisited.

Match the project's existing INDEX.md structure (typically organized by category: Code / Docs / External / Related repos). Show proposed additions, then ask:

> INDEX.md additions: [list]. Apply, or skip?

### Phase 4: CLAUDE.md (only if conventions changed)

CLAUDE.md is the project's schema and conventions file. It changes when:

- A new convention was established (e.g., "all new subdomains live in subfolders of this monorepo").
- An existing convention was overridden or refined.
- A new dependency or tool became part of the standard workflow.
- The build / deploy flow changed in a way that affects future work.

Most sessions do NOT need a CLAUDE.md update. If in doubt, skip it. Convention churn dilutes the file's value.

If something does qualify, draft the change as a minimal edit (a new paragraph in the relevant section, or a new subsection). Ask:

> CLAUDE.md convention update: [the change]. Apply, or skip?

### Phase 5: README.md (rarely)

README.md is for human-facing notes. Update only when:

- The user-visible surface of the project changed (a new entry point, a new way to run it).
- The setup steps to get the project running changed.
- A meaningful new feature shipped.

Most sessions skip this entirely. If it doesn't qualify, do NOT ask about it; just move on.

### Phase 6: Memory (only if new durable knowledge emerged)

Memory captures things that future Claude sessions on this machine need to know. It is NOT the same as LOG.md (which is per-project). Use memory when:

- New infrastructure was stood up that any session would need to use (a CLI, a tool, a credential location, a hostname).
- The user expressed a durable preference or correction that should govern future behavior.
- A reference to an external system was established (e.g., "bugs for X live in Linear project Y").
- A new tool or workflow pattern emerged that future sessions might forget exists.

Check the existing memory index at `~/.claude/projects/<project>/memory/MEMORY.md` first to avoid duplicates. If something is already covered, prefer updating the existing memory file over creating a new one.

Show the proposed memory entry (title + one-line summary + type) before writing. Ask:

> Save this as a new memory? [title + summary + type: user / feedback / project / reference]

If yes, write to `<memory-dir>/<slug>.md` with the standard frontmatter, then add a one-line entry to `MEMORY.md`. Refer to `~/.claude/CLAUDE.md` for the full memory format if unsure.

### Phase 7: Pencil wireframe demotion (only if applicable)

Skip this entire phase if no `.pen` files were edited this session OR no deploy happened this session.

If both conditions are met, do the sweep per `~/dev/CLAUDE.md`:

1. Identify which `.pen` files were touched this session.
2. For each one, use `mcp__pencil__get_editor_state` to find all frames with names starting with `🚧 NEW NEW `.
3. Cross-reference each candidate frame against what actually shipped (use the diff, the LOG entry you just wrote, and the commit messages).
4. For each frame whose content is now in production: remove the `🚧 NEW NEW ` prefix from the name AND remove the orange dashed stroke. Use the appropriate Pencil MCP tool to apply the changes.
5. If a frame is only partially shipped (some variants live, some not), leave the marker on the unshipped variants and demote only the ones that are real.
6. After demoting, add a brief note to the relevant LOG.md entry under `[<feature>][spec]` so the wireframe state stays auditable.

Show the list of frames to demote before applying. Ask:

> Demote these `🚧 NEW NEW` frames now that they've shipped? [list with frame names]

### Phase 8: Final summary

Once all phases are done (skipped or applied), end with a single one-line summary like:

> Closed out. Updated LOG.md (3 entries), INDEX.md (2 additions), saved 1 memory. CLAUDE.md and README.md unchanged. No Pencil sweep.

That's it. Do NOT print a long recap; the user already saw each step.

## Anti-patterns

Do not do any of the following. These are real failure modes this skill was designed against:

1. **Batching questions**. Never present a numbered list of questions or ask "do you want me to do A, B, C, and D?". Always one at a time, in the prominent format.
2. **Skipping the inventory phase**. If you jump straight to "want me to update LOG.md?", you'll miss things that happened earlier in the session that the user has already forgotten.
3. **Writing LOG entries that just restate what `git log` already says**. If the entry is "Added new field X to model Y", that's redundant. The entry should be "Picked X over Z because of constraint W" or "Hit gotcha A; root cause was B; fix is C". WHY, not WHAT.
4. **Updating CLAUDE.md to capture single-use decisions**. CLAUDE.md is for durable conventions, not ephemeral choices. If you're tempted to add a paragraph to CLAUDE.md, ask whether the same content belongs in LOG.md instead.
5. **Creating new memory entries that duplicate existing ones**. Read `MEMORY.md` first.
6. **Doing the Pencil demotion sweep without verifying what actually shipped**. Removing the `🚧` marker on something that didn't actually ship is worse than leaving it marked.
7. **Apologizing or summarizing what you're about to do**. Show the inventory, ask the focused question, apply, move on. The user wants speed.

## When in doubt

If you're not sure whether something belongs in LOG.md vs. INDEX.md vs. CLAUDE.md vs. memory:

- **WHY a decision was made** -> LOG.md
- **WHERE an artifact lives** -> INDEX.md
- **A convention that governs future work IN THIS PROJECT** -> CLAUDE.md
- **A convention that governs future work ACROSS PROJECTS** -> memory (feedback type)
- **A fact about external infrastructure** -> memory (reference type) AND mention in INDEX.md / CLAUDE.md if project-relevant
- **A user role / preference revealed in chat** -> memory (user type)

If still unsure, ask the user. One question, in the prominent format.
