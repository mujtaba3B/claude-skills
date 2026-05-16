# claude-skills . Project Log

Narrative + decision log for the `claude-skills` repo. For per-skill technical changes, see each skill's own history.

Format: date-headed sections, topic-tagged entries. One line per decision; expand inline if the *why* is non-obvious.

---

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
