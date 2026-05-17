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
. README.md          . public-facing install + usage
. install.sh         . symlinks every <skill>/ into ~/.claude/skills/
. handoff/
    . SKILL.md
    . spawn.sh       . optional skill-local helper script
. <next-skill>/
    . SKILL.md
. LOG.md             . local-only working log (gitignored)
. INDEX.md           . local-only working catalog (gitignored)
```

`LOG.md` and `INDEX.md` are kept by the maintainer locally and are not published. They are listed last because they do not ship with the repo. Anything in them is for the maintainer's own continuity, not for consumers of the repo.

A directory is a skill iff it contains a `SKILL.md`. `install.sh` skips anything else (so adding a `docs/` folder later wouldn't break install).

---

## Skill conventions

- **`SKILL.md` is the entry point.** Frontmatter must include `name` (matches the directory) and `description` (the triggering blurb Claude sees in the skills list). Body is the executable contract Claude follows when the skill is invoked.
- **`description` is load-bearing.** It's the only text Claude sees when deciding whether to trigger. Concrete trigger phrases beat abstract descriptions. Rewrite whenever the trigger surface changes.
- **No shared/ context files.** This repo is for standalone skills. If a skill grows shared dependencies with sibling skills, that's the signal to move it to `gstack-extensions/plugins/` instead.

---

## LOG.md and INDEX.md (local-only working files)

Both files are gitignored and exist only on the maintainer's machine. They serve the maintainer's own continuity across sessions, not anyone else.

When working in this repo as Claude, still maintain them per the cross-project schema in `~/dev/CLAUDE.md`. The triggers and format are unchanged:

- **LOG.md** captures *why* a decision was made (skill added/renamed/deprecated; architecture or trigger-surface change; repo-wide convention established or revised). Format: date-headed `## YYYY-MM-DD` sections; entries `### \`[topic][subtopic]\` Short title`. Skip every-commit noise; `git log` covers that.
- **INDEX.md** catalogs where artifacts live. Update when a skill is added/renamed/deprecated or a load-bearing external reference is added. Don't catalog every file inside every skill.

If a file is missing locally (e.g., a fresh clone), create it; nothing breaks.

---

## Release convention (CalVer + GitHub Releases)

This repo uses **calendar-versioned releases** (`v2026.05.17` format). Decided 2026-05-17. Rationale: a flat collection of standalone skills people copy-paste does not benefit from SemVer's breaking-change signal as much as it benefits from "you can see at a glance when something new shipped". GitHub Releases is the announcement surface; the version number just reinforces it.

### When to cut a release

**Every time a PR lands on `main`.** No release-less merges to `main`. If a PR is too trivial to release (typo fix in a README), it should not be on `main` in the first place; squash it into the next feature PR.

### Claude's prompt obligation

After merging any PR to `main` in this repo, surface this to the user before ending the session:

> Just merged to main. Per the CalVer convention this triggers a release. Want me to cut `v<today>` now? (Title, body summarising what's new, generated from the merged commits.)

If the user says yes, run the release workflow below. If no, log the deferral in `LOG.md` and move on. Do not silently skip the prompt.

### Release workflow

1. Tag format: `v2026.05.17`. If shipping twice in one day, append `.1`, `.2`, etc.: `v2026.05.17.1`.
2. Generate the release notes from the merged commits since the last tag:
   - **Added**: new skills.
   - **Changed**: meaningful updates to existing skills (new modes, restructures).
   - **Removed / renamed**: call these out prominently. Even with a shim, the user-facing slash command may have changed. People scanning the release notes need to know their muscle memory will break.
3. Create the release with `gh release create v<date> --title 'v<date>' --notes '<notes>' --target main`. Generate the notes via heredoc.
4. Append a one-line LOG entry under the day's section: `[meta][release] v<date> shipped: <one-line summary>` (local-only file; see the LOG/INDEX section above).

### What NOT to include in releases

- Internal refactors that don't change skill behavior (those don't justify a release on their own).
- Pure documentation tweaks (combine with the next real release).
- Branch-protection or repo-config changes (LOG-only, no release).

---

## When this file should be updated

If a repo-wide convention changes (new top-level file, new install behavior, new layout), update this file AND log it in LOG.md (local). Convention drift is the #1 reason schema files become useless.
