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
