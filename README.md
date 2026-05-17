# claude-skills

A small public collection of [Claude Code](https://claude.com/claude-code) skills by [@mujtaba3B](https://github.com/mujtaba3B).

Each directory in this repo is one skill: a `SKILL.md` file with YAML frontmatter that Claude Code auto-discovers from `~/.claude/skills/`. No build step, no plugin manifest, no marketplace. Clone the repo and either:

- run `./install.sh` to symlink every skill into your `~/.claude/skills/`, or
- copy any individual skill directory directly into your `~/.claude/skills/`.

## Install everything

```sh
git clone https://github.com/mujtaba3B/claude-skills.git ~/dev/public-claude-skills
cd ~/dev/public-claude-skills
./install.sh
```

Restart your Claude Code session. The skills become available by their slash-command name (e.g. `/handoff-prompt`).

## Install just one skill

If you only want one, you don't need the script. Just copy the folder:

```sh
cp -R claude-skills/handoff-prompt ~/.claude/skills/
```

That's it. Restart Claude Code.

## What's included

- **`/handoff-prompt`** . Snapshot the current task, decisions, and open questions into a self-contained prompt and copy it to your clipboard. Paste it into a fresh Claude Code session to continue without losing context. Useful when the conversation is getting long or you want to fork a clean parallel investigation.
- **`/close-out`** . End-of-session housekeeping for projects that keep `CLAUDE.md` / `LOG.md` / `INDEX.md` files at the repo root. Surveys what happened in the session (git activity, decisions made in chat, new files), drafts entries for each schema file in the project's existing voice, and applies them after you approve. If you don't use this three-file convention, skip this skill.
- **`/second-opinion`** . Get a second opinion on the current approach from another LLM. Four modes: `claude` (single Claude subagent), `codex` (single OpenAI opinion), `gemini` (single Gemini opinion), or `panel` (all three in parallel). Infers the ideal expert persona from the conversation, dispatches the same prompt to the chosen mode, and returns a concise synthesis instead of raw opinions. Panel mode includes a Steelman section when all three converge, as a guard against multi-model agreement theater. Requires the `codex` and `gemini` CLIs on `PATH` for those modes. `/expert-review` is kept as an alias that forwards to `/second-opinion panel`.
- **`/distill-question-and-answer-log-to-principles`** . Read a log of past `AskUserQuestion` answers from Claude's auto-memory directory, classify each one (durable principle, reinforces existing, conflicts with higher-priority instructions, or one-off), and propose new memory entries one at a time for you to approve. Goal: stop the same question from being re-asked across sessions. Pairs with a small capture hook (not bundled here; see the skill body for setup) that records each answer at the moment it is given.

## Updating

```sh
cd ~/dev/public-claude-skills
git pull
./install.sh   # idempotent; refreshes links and cleans stale ones
```

## Uninstall

Remove the symlinks from `~/.claude/skills/`:

```sh
for link in ~/.claude/skills/*; do
  [ -L "$link" ] && [[ "$(readlink "$link")" == *public-claude-skills* ]] && rm "$link"
done
```

## Contributing your own

This repo is intentionally a flat pile. To add a skill:

1. Create `<your-skill-name>/SKILL.md` with valid frontmatter (`name`, `description`).
2. Run `./install.sh`.
3. Restart Claude Code.

The `description` field is load-bearing: it's the only text Claude reads when deciding whether to trigger the skill on a user message. Make it concrete and trigger-rich.

## Related

- [gstack-extensions](https://github.com/mujtaba3B/gstack-extensions) . personal extensions to gstack (`/pr-watcher`, `/qa-headless`, PM Penny, Feature Frank).

## License

MIT.
