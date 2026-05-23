# mutwo-skills

Things I install on top of Claude Code to make it work the way I want. Published in case they're useful to you too.

![License](https://img.shields.io/github/license/mujtaba3B/mutwo-skills)
![Latest release](https://img.shields.io/github/v/release/mujtaba3B/mutwo-skills)

## Why this repo

Two kinds of upgrades to a standard Claude Code install live here:

- **Skills**: slash commands and agent personas Claude Code auto-loads (e.g. `/handoff`, `/second-opinion`).
- **Harness mods**: scripts and `~/.claude/settings.json` modifications that change how Claude Code itself behaves (e.g. a tab-color indicator that tells you which session needs your attention).

Both install with the same `install.sh`. Skills go in `skills/`, harness mods in `harness/`.

The name comes from my personal AI alias ("Mewtwo", second Mujtaba); the repo gets the spelling `mutwo-skills`. Sibling repo `mutwo` is reserved for the maintainer's private NanoClaw instance.

## Install

```sh
git clone https://github.com/mujtaba3B/mutwo-skills.git ~/dev/mutwo-skills
cd ~/dev/mutwo-skills
./install.sh
```

The picker prompts for what to install:
- Skills only
- Harness mods only
- Everything
- Pick individually

Or specify directly: `./install.sh skills`, `./install.sh harness`, `./install.sh all`.

Restart your Claude Code session afterward so it picks up the new skills and hook entries.

## What's in here

| Name | Type | What it does | Install |
|------|------|--------------|---------|
| [agent-files-architect](skills/agent-files-architect/) | Skill | Audits and selectively improves `CLAUDE.md` / `AGENTS.md` / `LOG.md` / `INDEX.md` / `MEMORY.md`. Produces a precedence graph, stale-pointer scan, gap list. | `./install.sh skills` |
| [close-out](skills/close-out/) | Skill | End-of-session housekeeping. Walks project docs and persistent memory to apply this session's decisions and durable knowledge. | `./install.sh skills` |
| [handoff](skills/handoff/) | Skill | Hands off the current work to a fresh Claude session (vertical iTerm2 split) or copies a self-contained handoff prompt to the clipboard. | `./install.sh skills` |
| [second-opinion](skills/second-opinion/) | Skill | Four modes: get a second opinion from Claude, Codex, Gemini, or a panel of all three in parallel. | `./install.sh skills` |
| [tab-state-indicator](harness/tab-state-indicator/) | Harness | Turns each Claude Code iTerm2 tab green when working and red when waiting on you. Plus a status-line summary of the last assistant message. | `cd harness/tab-state-indicator && ./install.sh` |

## Updating

```sh
cd ~/dev/mutwo-skills
git pull
./install.sh   # idempotent: refreshes skill symlinks, harness mods unchanged
```

Harness mods don't auto-update on `git pull`; re-run each mod's `install.sh` to pick up changes.

## Uninstall

Skills (symlinks):

```sh
for link in ~/.claude/skills/*; do
  [ -L "$link" ] && [[ "$(readlink "$link")" == *mutwo* ]] && rm "$link"
done
```

Harness mods: run each mod's own `uninstall.sh` (e.g. `cd harness/tab-state-indicator && ./uninstall.sh`). Each mod tracks its own settings.json entries via a sentinel tag so uninstall is location-independent.

## Contributing your own

Skills:

1. Create `skills/<your-skill-name>/SKILL.md` with valid frontmatter (`name`, `description`).
2. Run `./install.sh skills`.
3. Restart Claude Code.

The `description` field is load-bearing: it's the only text Claude reads when deciding whether to trigger the skill. Make it concrete and trigger-rich.

Harness mods:

1. Create `harness/<your-mod-name>/` with an `install.sh`, `uninstall.sh`, and a `README.md`.
2. Tag every hook entry with a sentinel string like `mutwo:<your-mod-name>` (use the shell `: sentinel;` prefix pattern; see `tab-state-indicator/install.sh` for a worked example).
3. Always validate `settings.json` JSON before and after merge; back up first.

## Related

- [gstack-extensions](https://github.com/mujtaba3B/gstack-extensions) - personal extensions to gstack (`/pr-watcher`, `/qa-headless`, PM Penny, Feature Frank).

## License

MIT.
