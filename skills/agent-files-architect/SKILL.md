---
name: agent-files-architect
description: Audit and selectively improve the user's first-class agent-loaded markdown files (CLAUDE.md, AGENTS.md, LOG.md, INDEX.md, MEMORY.md, plus any .md files referenced from a CLAUDE.md in the up-walk). Runs manually as a slash command and auto-fires inside `/close-out` when a TTL or activity trigger is hit. Produces a precedence graph, a stale-pointer scan, a context-weight report, a three-file gap list, and an INDEX.md link check; bundles only safe mechanical patches behind a single approval gate. Optional `--deep` mode walks downward from cwd. Optional `--research` flag fetches upstream guidance from Anthropic, OpenAI Codex, Cursor, Copilot, and agents.md to surface drift. Optional `--review` flag fires `/second-opinion panel`. Trigger when the user says "/agent-files-architect", "architect the agent files", "audit agent files", "tidy CLAUDE.md", "refresh agent files", "check agent docs", or any variant of "are my CLAUDE.md / AGENTS.md / LOG.md / INDEX.md / MEMORY.md still in good shape". Voice triggers (speech-to-text aliases): "architect the agent files", "audit agent files", "tidy claude dot em dee", "refresh agent files", "check agent docs".
---

# Agent files architect

Audits and selectively improves the markdown files that AI coding agents read on every session. Not for human-facing docs (README, CHANGELOG, CONTRIBUTING, ARCHITECTURE); those are owned by `/document-release` and `/end-sprint`.

In scope:

- Core: `CLAUDE.md`, `AGENTS.md`, `LOG.md`, `INDEX.md`, `MEMORY.md`.
- Dynamic: any `.md` file referenced (by relative or absolute path) from a CLAUDE.md anywhere in the traversal. This is how `WIREFRAMES.md`, `STANDARD.md`, `TOOLING.md`, `DESIGN.md`, `PRINCIPLES.md`, etc. get pulled in without a hardcoded list.
- Editor-specific: `.cursorrules`, `.cursor/rules/*`, `.github/copilot-instructions.md` when present.

Out of scope (do not touch): `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`.

---

## Step 0: Resolve mode and refuse bad invocations

Parse flags from the slash arg: `--deep`, `--research`, `--review`, `--close-out`. All optional, all off by default.

`--close-out` is the marker that says "you were invoked by /close-out, run silently, no menu, no extras". The first three are user-facing flags.

Refuse to run if cwd is `/`:

> Refusing to run from `/`. Cd into a project directory first; the architect needs a useful starting point.

### Step 0.5: Mode menu (cold invocation only)

If ALL of the following are true, present a mode-selection menu via `AskUserQuestion` before running anything:

- No user flag was passed (`--deep`, `--research`, `--review` all absent).
- `--close-out` was not passed.

The menu is a single-select with four options:

| Option label | Description | Flag set |
|---|---|---|
| Standard audit (recommended) | Up-walk only. Precedence graph, stale pointers, size report, three-file gap, INDEX link check. Fast. | (none) |
| Deep audit | Adds a downward walk into `~/dev/` subdirs to catch AGENTS.md and CLAUDE.md hidden in repos. Honors `.gitignore` and `.agent-doctor-ignore`. | `--deep` |
| Standard + research drift | Adds an upstream-guidance fetch (Anthropic memory docs, Codex AGENTS.md, Cursor rules, agents.md) via `/browse` and surfaces drift. | `--research` |
| Standard + expert panel | Adds a `/second-opinion panel` review of the audit output. | `--review` |

`header` is "Mode". Question text: "Which audit mode? Standard is fine if you're not sure."

Combinations (e.g., `--deep --research`) remain available to power users via direct flags. The menu is for first-time and cold invocations; it intentionally keeps the choice space small.

After selection, treat the chosen flag as if it had been passed on the command line, then continue to the roadmap print and Step 1.

If `--close-out` was passed: skip the menu, skip Steps 7 and 8 unconditionally, and target the whole run under 2 seconds. Apply the trigger gate as documented in "Trigger gate from /close-out".

### Roadmap

Print a one-line roadmap so the user can follow:

```text
agent-files-architect plan:
- ⏳ 1. Discover in-scope files (up-walk[, deep])
- ⏳ 2. Build precedence graph
- ⏳ 3. Stale-pointer + context-weight + INDEX link check
- ⏳ 4. Three-file gap report (advisory)
- ⏳ 5. Bundle safe mechanical patches
- ⏳ 6. Single approval gate
- ⏳ 7. (optional) --research drift scan
- ⏳ 8. (optional) --review /second-opinion panel
- ⏳ 9. Write report and update .last-run flag
```

When called from `/close-out` (i.e., `--close-out` passed), the menu is bypassed and steps 7 and 8 are skipped unconditionally; whole-run budget under 2 seconds.

---

## Step 1: Discover in-scope files

### Up-walk (always on)

Walk from cwd up to `$HOME`. At each level, look for:

```text
CLAUDE.md, AGENTS.md, LOG.md, INDEX.md, MEMORY.md,
.cursorrules, .cursor/rules, .github/copilot-instructions.md
```

Always also include:

- `~/.claude/CLAUDE.md` (Claude Code's user-level memory file, always loaded).
- Any sibling `.md` spec files in dirs that already host a CLAUDE.md (e.g., `WIREFRAMES.md`, `STANDARD.md`, `TOOLING.md`, `DESIGN.md` next to a CLAUDE.md).
- `~/.claude/projects/<project-slug>/memory/MEMORY.md` matching the current project, plus the `feedback_*.md` and `question_and_answer_decision_*.md` files in that dir, when the auto-memory system is in use.

For each CLAUDE.md found, scan for inline pointers to other `.md` files (regex on relative paths and on absolute paths under `$HOME`) and pull those into the in-scope set. One hop only, no recursion: a referenced spec does not get its references followed.

### Symlink handling

Capture the inode for each discovered file. macOS/BSD uses `stat -f %i <path>`; GNU/Linux uses `stat -c %i <path>`. Detect the platform with `uname -s` (Darwin = BSD syntax, anything else = GNU syntax). Dedupe by inode. Never write to a path whose inode also belongs to a path outside cwd's project tree.

### Deep mode (`--deep` opt-in only)

Walk DOWN from cwd, depth cap 4. Skip:

- Standard exclusions: `node_modules`, `.venv`, `venv`, `__pycache__`, `.git`, `dist`, `build`, `.next`, `.cache`, `target`.
- Anything matching a `.gitignore` entry in any ancestor.
- Any dir containing a `.agent-doctor-ignore` file (zero-byte file is fine; presence is the signal).

Content-heuristic to decide if a CLAUDE.md found via deep mode looks user-authored:

- Mentions the user's name, a three-file (`CLAUDE.md` / `LOG.md` / `INDEX.md`) convention, project-specific brand or domain terms, or matches a workspace layout the user maintains: user-authored, include.
- Contains "Generated by", "Auto-generated", "Do not edit", or is a copy of a template under `node_modules`-adjacent paths: vendored, skip and recommend adding `.agent-doctor-ignore`.

### One parallel discovery batch

Run discovery in a single parallel bash invocation: one `find` for the up-walk file names plus a `find -maxdepth 4` for deep mode if enabled, both writing to temp files. Then a single parallel batch of `Read` calls for every discovered file at once. Do not Read-then-Read serially.

---

## Step 2: Build the precedence graph (primary artifact)

For every rule topic that appears in two or more in-scope files, render a graph node.

Topic detection: scan each file for headers (h1, h2, h3) and lead sentences of paragraphs. Cluster topics by keyword overlap (em-dash rule, gstack usage, design tool preference, three-file mandate, karpathy gist check, question-and-answer loop, etc.). Imperfect clustering is fine; v1 favors visibility over precision.

Authoritative-wins hierarchy (highest first):

1. `~/.claude/CLAUDE.md` (Claude Code's user-level memory)
2. Any intermediate `CLAUDE.md` found in the up-walk between `~/.claude/` and the project (e.g., a workspace-level `CLAUDE.md` if the user keeps one)
3. Project `CLAUDE.md` (closest to cwd that is not one of the above)
4. `feedback_*.md` in the project memory dir
5. `question_and_answer_decision_*.md` in the project memory dir

Render `precedence.md` as a list of topics; each topic shows:

- The authoritative file.
- All other files that co-mention the topic, with one-line excerpt.
- A `CONTRADICTION` flag if a lower-tier file states something incompatible with the higher-tier file. Flag only, never auto-resolve.

Co-mentions that are *consistent restatements* are surfaced as redundancy candidates but not contradictions.

---

## Step 3: Stale-pointer + context-weight + INDEX link check

Run these three in parallel.

### Stale-pointer scan

For each in-scope file, regex out every relative path mention (`(\./|\.\./|[a-zA-Z0-9_./-]+\.(md|pen|json|yml|yaml|toml|py|ts|tsx|sh))`) plus every absolute path under `$HOME`. For each, `test -e` the path. Collect misses.

### Size report (no caps)

For every agent-loaded file, record:

- Size in bytes.
- Approximate tokens = bytes / 4.
- Top three heaviest sections by header span (rough scan).

Write the table to `context-weight.md`. Do not flag over/under verdicts. There is no published Anthropic guidance for CLAUDE.md byte budgets, and any hard cap the skill imposes is vibes, not research. The user reviews sizes and decides whether anything looks bloated.

If/when measured guidance emerges (Anthropic doc, community benchmark, internal experiment), revisit and add thresholds. Until then, the skill reports and the user judges. The real quality signal is organization, concision, and absence of repetition: precedence-graph contradictions and redundancy candidates carry that load, not raw bytes.

### INDEX.md link check

For each INDEX.md found, parse markdown tables for link targets. `test -e` each. Misses go in the report.

---

## Step 4: Three-file gap report (advisory)

For each repo (defined as any dir under `~/dev/` containing a `.git/` directory) discovered during traversal:

- Check for presence of `CLAUDE.md`, `LOG.md`, `INDEX.md`.
- If any are missing, classify the repo:
  - User-authored (matches the dev/ pattern, has commits authored by the user's git email, contains brand or domain text): "looks user-authored, recommend bootstrap".
  - Vendored or unowned (forked, contains "Generated by", or has `node_modules`-style markers): "looks vendored, suggest add `.agent-doctor-ignore`".

This section is advisory only. Never create placeholder files.

---

## Step 5: Bundle safe mechanical patches

Patches eligible for the bundle:

- Broken relative paths that have an obvious nearby corrected target (e.g., file moved, new path inferable from `git log --diff-filter=R`).
- Missing routing pointer-line: when a sibling spec exists (e.g., `WIREFRAMES.md`) but the local `CLAUDE.md` does not mention it, add a single-line pointer in the appropriate section.
- Date-format normalization in `LOG.md` headers: convert `## 5/17/2026` or `## May 17, 2026` to `## 2026-05-17`.
- `INDEX.md` table-link repointing when the link is broken and the renamed target is discoverable.

Never in the bundle:

- Prose rewrites.
- LOG.md archive splits.
- Contradiction resolutions between precedence-graph nodes.
- Anything that touches a `feedback_*.md` or `question_and_answer_decision_*.md` (those have their own write path through the distill skill).

Render `proposed-patches.diff` as a single unified diff covering the bundle. Render proposals-only items as a separate "Proposals (not bundled)" section in `report.md`.

---

## Step 6: Single approval gate

Print a tight summary (5 to 12 bullets), then ask one question:

```text
---

### ❓ QUESTION

> Apply these N safe fixes? [y/N/show diff]

---
```

Branching:

- `y`: apply all patches in one parallel `Edit` batch. Update `.last-run` flag. Write final report and proceed to Step 9.
- `show diff`: print `proposed-patches.diff` verbatim, then re-ask the same question.
- `N` (default): save the report without applying. Update `.last-run` either way (manual or close-out): the audit itself is the value, and the trigger gate already qualified the close-out invocation. The `.last-run` write rule is owned by Step 9 (single source of truth).

No per-patch confirmation. The bundle is the unit.

---

## Step 7: `--research` drift scan (manual only)

Skip silently when not invoked with `--research`.

Sources (fetch via `/browse` from gstack, not `WebFetch` or `WebSearch`; this is a global rule in `~/.claude/CLAUDE.md`):

- Karpathy gists: piggyback on `~/.claude/karpathy-seen.json`. Read the snapshot. If a gist has been updated since the agent-files-architect last run, include it.
- Anthropic Claude Code memory + settings docs: https://docs.anthropic.com/en/docs/claude-code/memory
- OpenAI Codex AGENTS.md guidance: https://developers.openai.com/codex
- Cursor rules docs: https://docs.cursor.com/context/rules
- GitHub Copilot custom instructions: https://docs.github.com/en/copilot
- Community spec: https://agents.md/

For each source, summarize the page in 2 to 4 bullets and compare against the user's actual files. Each finding cites:

- Source URL.
- The user file that drifts from the upstream guidance.
- One-line "what changed" and "why this matters".

Append to `research.md` and link from `report.md`.

---

## Step 8: `--review` expert review (manual only)

Skip silently when not invoked with `--review`.

Compose a self-contained prompt from the audit findings:

- Subject: "Review the audit output produced by /agent-files-architect for this user's CLAUDE.md / AGENTS.md / LOG.md / INDEX.md / MEMORY.md setup."
- Persona: "developer-experience lead designing meta-tools for AI coding agents."
- Constraints in play: the user's three-file mandate, the em-dash ban, the gstack `/browse` rule, the manual-only stance on auto-firing research and panels.
- Attach the report inline.

Fire `/second-opinion panel`. Save the panel output alongside the audit artifacts and link from `report.md`.

Never auto-fire. The flag is the gate.

---

## Step 9: Write artifacts and update flag

Output layout (all under `~/.claude/agent-files-architect/`):

```text
~/.claude/agent-files-architect/
  <ISO-TS>/                      e.g. 2026-05-17T08-30-00/
    report.md
    precedence.md
    context-weight.md
    proposed-patches.diff
    research.md                  (only if --research)
    panel/                       (only if --review; mirrors /second-opinion output dir)
  latest -> <ISO-TS>/            (symlink, always points at most recent run)
  .last-run                      (epoch seconds, single line)
```

ISO timestamp uses dashes-only format so it works as a directory name across platforms: `date -u +%Y-%m-%dT%H-%M-%S`.

`.last-run` write rule:

- Manual run: always update on completion, regardless of approval gate outcome.
- Close-out invocation: update only if at least one of the audit checks ran (i.e., the trigger gate fired).

v1 does not prune old runs.

---

## Step 10: Final chat summary

5 to 12 bullets, grouped by severity. Example shape:

```text
Findings (this run):

- 1 contradiction surfaced (em-dash rule mentioned in 3 files; project CLAUDE.md restates without conflict).
- 2 stale pointers: ~/dev/businesses/unbound/INDEX.md links to spec/wireframes.pen (moved to spec/wires.pen).
- Sizes reported for 8 files (heaviest: ~/.claude/CLAUDE.md at 8.2 KB, top sections in context-weight.md).
- 1 INDEX.md broken link.
- 1 three-file gap: ~/dev/karpathy-skills/ missing INDEX.md (looks user-authored, recommend bootstrap).
- 4 safe patches bundled; 2 proposals not bundled (prose rewrites, see report).
- Report: ~/.claude/agent-files-architect/latest/report.md
```

Final line always points at `~/.claude/agent-files-architect/latest/report.md`.

---

## Trigger gate from `/close-out`

`/close-out` should call this skill at a fixed point in its sequence (after Step 5 distill, before Step 6 summary). The hook is conditional: the architect runs only if ONE of these is true.

```bash
FLAG="$HOME/.claude/agent-files-architect/.last-run"
NOW=$(date +%s)
LAST=$(cat "$FLAG" 2>/dev/null || echo 0)
AGE_DAYS=$(( (NOW - LAST) / 86400 ))

# Trigger 1: days since last run >= 7
T1=$([ "$AGE_DAYS" -ge 7 ] && echo 1 || echo 0)

# Trigger 2: sessions since last run >= 10
# Count session files newer than .last-run in this project's Claude Code
# session dir. The slug is derived from cwd: Claude Code stores per-project
# session state at ~/.claude/projects/<slug>/ where <slug> is the absolute
# path with / replaced by -. If the dir does not exist (first session in
# this project), find returns nothing and the trigger silently does not fire.
PROJECT_SLUG=$(printf '%s' "$PWD" | sed 's|/|-|g')
PROJECT_DIR="$HOME/.claude/projects/$PROJECT_SLUG"
SESSIONS_NEW=$(find "$PROJECT_DIR" -type f -newer "$FLAG" 2>/dev/null | wc -l | tr -d ' ')
T2=$([ "$SESSIONS_NEW" -ge 10 ] && echo 1 || echo 0)

# Trigger 3: agent files touched this session >= 3
# (Computed in the close-out caller, passed in via env var or arg.)
T3="${AGENT_FILES_TOUCHED_THIS_SESSION:-0}"
T3=$([ "$T3" -ge 3 ] && echo 1 || echo 0)

if [ "$T1$T2$T3" = "000" ]; then
  echo "agent-files-architect: no trigger; silent skip"
  exit 0
fi
```

When fired from close-out: up-walk only (no `--deep`), no `--research`, no `--review`. Target whole-run budget under 2 seconds. Apply the single approval gate inline before close-out's final summary. If user declines the bundle, save the report and continue close-out.

If no trigger fires, stay silent. Do not touch the `.last-run` flag (so the staleness countdown keeps ticking).

**Follow-up edit required to `/close-out`'s SKILL.md**: insert a "Step 5.5: agent-files-architect" subsection (or extend Step 5) that invokes the trigger gate and runs this skill conditionally. Do not perform that edit in the same task as this skill's authoring; surface it as a follow-up.

---

## Anti-patterns

The /second-opinion panel that vetted this skill flagged seven failure modes. The skill is built to avoid all of them.

1. **Bidirectional traversal by default.** Down-walking blindly hits vendored code under `~/dev/`. Up-walk is default; `--deep` is opt-in with depth cap 4, standard exclusions, `.gitignore` honor, `.agent-doctor-ignore` opt-out, and content-heuristic gating.
2. **Touching human-facing docs.** README, CHANGELOG, CONTRIBUTING, ARCHITECTURE are out of scope. Those are owned by `/document-release` and `/end-sprint`. Mention them only to redirect.
3. **Auto-firing the research step.** Background fetches of upstream docs become theater that decays into stale snapshots. `--research` is manual only.
4. **Auto-firing `/second-opinion panel` on drift.** Guru-shopping at scale. `--review` is manual only.
5. **Slowing down `/close-out`.** Mandatory triggers gate the close-out hook: 7 days, 10 sessions, or 3 files touched. Target under 2 seconds when fired.
6. **Auto-managed sentinel comments.** No `<!-- agent-managed -->` markers anywhere. They rot, get accidentally deleted, get duplicated. Source-of-truth comparison via the precedence graph is the alternative.
7. **Bootstrap hallucination.** The three-file gap report is advisory. Never create placeholder CLAUDE.md / LOG.md / INDEX.md files. The user's `/dev/CLAUDE.md` bootstrap protocol is owned by humans plus the reference implementation, not by this skill.

Additional rules:

- No em-dashes in any output of this skill (reports, diffs, chat summaries, file edits). Use period, comma, colon, semicolon, parens, or hyphen.
- All web fetches go through `/browse` (gstack), never `WebFetch` or `WebSearch`.
- One question at a time, in the prominent `### ❓ QUESTION` block, last thing in the response. The approval gate in Step 6 is the canonical example.
- Discovery, reads, and edits run in parallel batches, not serially.
- Never write to a path whose inode also belongs to a path outside the project tree (symlink safety).
