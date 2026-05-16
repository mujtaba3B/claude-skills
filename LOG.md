# claude-skills . Project Log

Narrative + decision log for the `claude-skills` repo. For per-skill technical changes, see each skill's own history.

Format: date-headed sections, topic-tagged entries. One line per decision; expand inline if the *why* is non-obvious.

---

## 2026-05-16

### `[skill][expert-review]` Added `/expert-review` for fast three-LLM second opinions
Need: while collaborating with Claude on an idea, the user often wants an outside expert opinion before committing. The desired pattern is a panel: Claude, OpenAI, and Gemini each role-play the ideal expert for the situation, in parallel, and Claude distills their feedback into adjustments to the current direction.

Existing options considered and rejected:
- gstack `/codex` consult: only one outside opinion (OpenAI), no Gemini, no synthesis layer. Useful, but a single voice.
- gstack `/benchmark-models`: measures model performance on a prompt (latency, tokens, cost). Wrong purpose. That's model selection, not idea critique.
- gstack `/autoplan`: chains Claude reviewer personas (CEO, eng, design, DX). All same model, no outside opinion.

Chosen shape: skill auto-bundles recent conversation context, infers the ideal expert persona from that context (with optional user hint), composes one self-contained prompt, fans out in parallel to a Claude subagent + `codex exec` + `gemini -p`, saves all three responses to `/tmp/expert-review-<ts>/{claude,openai,gemini}.md`, and returns ONLY a concise synthesis of suggested adjustments. Full opinions surface only on follow-up request.

Lives in `public-claude-skills/` (not `gstack-extensions/`) because the skill has no gstack dependency: it just shells out to `codex` and `gemini` and uses the standard `Agent` tool. Publicly useful as a standalone pattern.

## 2026-05-14

### `[meta][repo]` Created the repo as a public home for standalone Claude Code skills
Existing layouts considered and rejected:
- `mj-claude` (the now-archived marketplace repo): plugin manifest + `/plugin marketplace add` flow felt heavyweight for what are single-file skills. Reads as "distribution platform" cosplay.
- Folding into `gstack-extensions`: the name implies "extends gstack", and these skills are standalone. Splitting personal skills across two repos by relationship-to-gstack is the right cut.
- Repo at `~/.claude/skills/public/`: couples the author's dotfile layout to other people's clone path. Optimizes for author over audience.

Chosen layout: flat directories at the repo root, each with a `SKILL.md`. No `skills/` wrapper since the repo *is* skills. `install.sh` symlinks every skill folder into `~/.claude/skills/`. Skill folders can also be copied directly with `cp -R <skill> ~/.claude/skills/` for users who want one without cloning the rest.

Local folder is `~/dev/public-claude-skills/`; GitHub repo is `mujtaba3B/claude-skills`. The "public-" local prefix is intentional: when a sibling `private-claude-skills/` exists later (for the `streak/` workflow), the pair will read symmetrically.

### `[skill][handoff-prompt]` First skill seeded into the repo
Moved `~/.claude/skills/handoff-prompt/` (real folder, no prior git home) into the repo. Replaced with a symlink via `install.sh`. Prior risk: skill existed only locally, would have been lost on laptop failure.

## 2026-05-15

### `[skill][close-out]` Added `/close-out` for end-of-session housekeeping
Need: after a substantive working session, decisions made in chat (the WHY) never make it to LOG.md, new files get added without an INDEX.md entry, new infra gets stood up without a memory note. The personal convention (CLAUDE.md / LOG.md / INDEX.md per repo) only pays off if it stays current; manual discipline was unreliable.

Existing options considered and rejected:
- `/document-release` from gstack: scoped to public release docs (README, CHANGELOG, VERSION bump). Wrong layer. The new skill is about *internal* project-keeping for a single working session, not release ceremony.
- `/end-sprint` from gstack: also includes `/document-release` plus retro/health/save. Too heavy for "I'm pausing for the day"; the per-session housekeeping is a smaller, more frequent need.
- One mega-skill that does close-out + handoff + context-save: would have overlapping triggers and unclear boundaries. Kept narrow.

Skill walks LOG.md (almost always), INDEX.md (only if new artifacts), CLAUDE.md (only if conventions changed), README.md (rarely), and persistent memory (only if new durable cross-session knowledge emerged). Also handles the Pencil `🚧 NEW NEW` mockup demotion sweep when both a `.pen` was touched AND a deploy happened.

Hard-codes the user's interaction style: one question at a time in the prominent `### ❓ QUESTION` format, no em-dashes, no batched lists. Seeded by dogfooding it on the mujtab.ai + namecheap-cli + cloudflare-token sprint where the absence of this discipline showed up as scattered LOG entries written defensively, mid-session.

### `[meta][protection]` Enabled branch protection on `main`
Initial pushes (both the repo init and the close-out skill addition) went straight to `main` with no PR. For a public repo where the README invites people to clone, that's a real gap: no CI gate, no commit-message style enforcement, no forced final read-through.

Enabled via `gh api -X PUT /repos/mujtaba3B/claude-skills/branches/main/protection` with: `required_pull_request_reviews` (count 0, so solo workflow still works), `required_conversation_resolution` true, `enforce_admins` false (so admin can override in emergencies), force pushes blocked, deletions blocked. From now on even solo work must go through a PR.

### `[skill][close-out]` v2: applied-first, no per-phase previews
Dogfooded the v1 skill on the close-out for this session. Three problems surfaced:
1. The skill previewed every drafted entry in a table and asked for approval at each phase. User wanted "do it and summarize at the end", not "preview, approve, apply, repeat".
2. Edits were applied sequentially across multiple repos, when parallel tool calls would have been faster.
3. The 7-phase structure encouraged ask-gates at every step instead of one batched apply.

Rewrote the skill: default mode is APPLY-FIRST, parallel tool calls everywhere, one-line summary at the end. Per-phase questions removed; only ask when a decision is genuinely ambiguous (e.g., "this LOG entry could go in repo A or B"). Added explicit anti-patterns covering sequential tool calls, re-reading files after edits, and previewing entries. Memory: see `close-out-no-preview`.
