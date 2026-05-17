# mutwo

Things I install on top of Claude Code to make it work the way I want. Published in case they're useful to you too.

![License](https://img.shields.io/github/license/mujtaba3B/mutwo)
![Latest release](https://img.shields.io/github/v/release/mujtaba3B/mutwo)

## Why this repo

Two kinds of upgrades to a standard Claude Code install live here:

- **Skills**: slash commands and agent personas Claude Code auto-loads (e.g. `/handoff`, `/second-opinion`).
- **Harness mods**: scripts and `~/.claude/settings.json` modifications that change how Claude Code itself behaves (e.g. a tab-color indicator that tells you which session needs your attention).

Both install with the same `install.sh`. Skills go in `skills/`, harness mods in `harness/`. See [`MODS.md`](MODS.md) for the full catalog.

The name comes from my personal AI alias ("Mewtwo", second Mujtaba); the repo gets the spelling `mutwo`.

## Install

```sh
git clone https://github.com/mujtaba3B/mutwo.git ~/dev/mutwo
cd ~/dev/mutwo
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

See [`MODS.md`](MODS.md) for the full scannable table. Short list:

- **Skills**: `/handoff`, `/close-out`, `/second-opinion`, `/distill-question-and-answer-log-to-principles`, `/agent-files-architect`
- **Harness**: `tab-state-indicator` (iTerm2 tab color + status-line summary)

## Updating

```sh
cd ~/dev/mutwo
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
