# claude-skills

Personal Claude Code skills for project documentation, session handoffs, and second opinions from multiple LLMs.

![License](https://img.shields.io/github/license/mujtaba3B/claude-skills)
![Latest release](https://img.shields.io/github/v/release/mujtaba3B/claude-skills)
![Skills](https://img.shields.io/badge/skills-4-blue)

## Why this repo

These are skills I use in my own Claude Code sessions, published in case they're useful to someone else. The repo is intentionally a flat pile: each directory is one standalone skill (a `SKILL.md` file with YAML frontmatter that Claude Code auto-discovers from `~/.claude/skills/`). No plugin manifest, no marketplace, no build step. Clone or copy what you want.

## Install

Clone the repo and run `install.sh` to symlink every skill into your `~/.claude/skills/`:

```sh
git clone https://github.com/mujtaba3B/claude-skills.git ~/dev/public-claude-skills
cd ~/dev/public-claude-skills
./install.sh
```

Restart your Claude Code session. The skills become available by their slash-command name (e.g. `/handoff-prompt`).

### Install just one

If you only want one, copy the folder directly:

```sh
cp -R claude-skills/handoff-prompt ~/.claude/skills/
```

Restart Claude Code.

## Skills

| Skill | Does what |
|---|---|
| [`/handoff-prompt`](handoff-prompt/SKILL.md) | Snapshot the current task, decisions, and open questions into a self-contained prompt and copy it to your clipboard. Paste into a fresh Claude Code session to continue without losing context. |
| [`/close-out`](close-out/SKILL.md) | End-of-session housekeeping for projects that keep `CLAUDE.md` / `LOG.md` / `INDEX.md` files at the repo root. Surveys what happened in the session, drafts entries for each schema file, and applies them after you approve. |
| [`/second-opinion`](second-opinion/SKILL.md) | Get a second opinion from another LLM. Four modes: a single opinion from Claude (subagent), Codex (OpenAI), or Gemini, or a panel of all three in parallel. Returns a concise synthesis instead of raw opinions. Requires `codex` and `gemini` CLIs on `PATH` for those modes. |
| [`/distill-question-and-answer-log-to-principles`](distill-question-and-answer-log-to-principles/SKILL.md) | Reads a log of past `AskUserQuestion` answers, classifies each one, and proposes new memory entries for you to approve. Goal: stop the same question from being re-asked across sessions. |

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
