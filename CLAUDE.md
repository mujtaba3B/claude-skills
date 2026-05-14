# claude-skills . Project Schema (Claude instructions)

This file is the schema for the `claude-skills` repo. It applies to every Claude Code session started under `/Users/mujtaba/dev/public-claude-skills/`.

The pattern follows the cross-project schema at `/Users/mujtaba/dev/CLAUDE.md`.

---

## What this repo is

A small public collection of standalone Claude Code skills. Each top-level directory is one skill (a `SKILL.md` with YAML frontmatter); there is no plugin manifest, no marketplace, no shared context files between skills.

Local folder is `~/dev/public-claude-skills/`; public GitHub repo is `mujtaba3B/claude-skills`. The folder-name and repo-name differ on purpose: locally the "public-" prefix signals "publishable, safe to share"; publicly the simpler name reads cleanly.

The repo is intentionally flat. No `skills/` subdirectory: the repo *is* skills. A future restructure to add `lib/` or `docs/` would justify nesting; until then, don't pre-build scaffolding.

---

## Repo layout

```
~/dev/public-claude-skills/
. CLAUDE.md          . this file
. LOG.md             . chronological decision log
. INDEX.md           . content catalog
. README.md          . public-facing install + usage
. install.sh         . symlinks every <skill>/ into ~/.claude/skills/
. handoff-prompt/
    . SKILL.md
. <next-skill>/
    . SKILL.md
```

A directory is a skill iff it contains a `SKILL.md`. `install.sh` skips anything else (so adding a `docs/` folder later wouldn't break install).

---

## Skill conventions

- **`SKILL.md` is the entry point.** Frontmatter must include `name` (matches the directory) and `description` (the triggering blurb Claude sees in the skills list). Body is the executable contract Claude follows when the skill is invoked.
- **`description` is load-bearing.** It's the only text Claude sees when deciding whether to trigger. Concrete trigger phrases beat abstract descriptions. Rewrite whenever the trigger surface changes.
- **No shared/ context files.** This repo is for standalone skills. If a skill grows shared dependencies with sibling skills, that's the signal to move it to `gstack-extensions/plugins/` instead.

---

## LOG.md . when to update

Narrative + decision log. Captures *why* and *what was decided*, not every commit.

### Triggers
- A skill is added, renamed, or deprecated.
- A skill's architecture or trigger surface changes meaningfully.
- A repo-wide convention is established or revised.
- A user preference about how this repo is maintained is captured.

### Anti-triggers
- Every commit (git log already has it).
- Typo fixes inside a skill body.

### Format
- Date-headed sections: `## YYYY-MM-DD`.
- Entries: `### \`[topic][subtopic]\` Short title`, then 1-4 lines of body.
- Topic tags: `[meta]`, `[skill]`, `[infra]`. Subtopics typically the skill name.

---

## INDEX.md . when to update

Update when a skill is added/renamed/deprecated or when a load-bearing external reference is added. Don't catalog every file inside every skill.

---

## When this file should be updated

If a repo-wide convention changes (new top-level file, new install behavior, new layout), update this file AND log it in LOG.md. Convention drift is the #1 reason schema files become useless.
