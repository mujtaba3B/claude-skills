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

- **`/handoff-prompt`** . Generate a self-contained handoff prompt that a fresh Claude Code session can pick up from. Snapshots the current task, decisions, file paths, conventions, and open questions, and copies the prompt to your clipboard so you can paste it into a new session with Cmd+V. Useful when context is getting long, or when you want to fork off a parallel investigation in a clean session.
- **`/close-out`** . End-of-session housekeeping for projects that follow the `CLAUDE.md` / `LOG.md` / `INDEX.md` plus persistent memory convention. Surveys what happened (git activity, decisions made in chat, new infra), walks each schema file one at a time, drafts entries in the project's existing voice, and applies after you approve. Also handles the Pencil `🚧 NEW NEW` mockup demotion sweep when a deploy happened. Distinct from `/document-release`: this is about your internal project-keeping discipline, not public-facing release docs.
- **`/expert-review`** . Get a fast second opinion from three LLMs in parallel. Claude (as a subagent), OpenAI (via the `codex` CLI), and Gemini (via the `gemini` CLI) each role-play the ideal expert for whatever you're working on. The skill infers the ideal persona from the current conversation, fans out the same prompt to all three, saves their full responses to `/tmp/expert-review-<ts>/`, and returns a concise synthesis of the adjustments they'd recommend. Requires `codex` and `gemini` CLIs on PATH.

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

- [gstack](https://github.com/garrytan/gstack) . the larger Claude Code toolkit these skills sit alongside in `~/.claude/skills/`.
- [gstack-extensions](https://github.com/mujtaba3B/gstack-extensions) . personal extensions to gstack (`/pr-watcher`, `/qa-headless`, PM Penny, Feature Frank).

## License

MIT.
