---
name: karpathy-gist-check
description: Check Andrej Karpathy's public gists for new or updated entries since the last seen baseline. Trigger automatically on session start when `~/.claude/karpathy-last-check` is missing or older than 30 days. Also invoke manually when the user says "check karpathy gists", "/karpathy-gist-check", or "any new karpathy posts". Defers if the user is mid-task; runs at most once per session.
license: MIT
---

# Karpathy gist check

Karpathy publishes design patterns and mental models for working with LLMs in his public gists. They sometimes change how core working patterns (like the LLM Wiki) should be set up. This check runs on a ~30 day cadence to surface new or updated gists.

## When to run

- **Auto-trigger:** On session start, if `~/.claude/karpathy-last-check` is missing or its date is more than 30 days before today.
- **Manual trigger:** User asks to check Karpathy's gists.
- **Defer if the user is mid-task.** Wait for a natural break. Better to skip a check than derail active work.
- **At most once per session**, even if the staleness file still looks stale after the first run.

## Procedure

1. Use `/browse` (from gstack) to fetch `https://gist.github.com/karpathy` and extract the gist list: id, title, last-active date.
2. Compare against `~/.claude/karpathy-seen.json` (the seen baseline).
3. If anything is new or has been updated since the seen baseline:
   - List new/changed gists, one line each (`id  title  last_active`).
   - Ask the user whether to read any of them now or defer.
4. Overwrite `~/.claude/karpathy-last-check` with today's date (`YYYY-MM-DD`).
5. Overwrite `~/.claude/karpathy-seen.json` with the fresh snapshot.

## First-time setup

If `~/.claude/karpathy-seen.json` doesn't exist:
- Fetch the gist list fresh.
- Treat all current gists as the baseline (do NOT surface them as "new"; the protocol is for *changes* going forward).
- Write the baseline and today's date as above.

## Notes

- Use `/browse`, not WebFetch, per the gstack rule in `~/.claude/CLAUDE.md`.
- Date format for `karpathy-last-check`: `YYYY-MM-DD` on a single line, no trailing newline issues.
- `karpathy-seen.json` shape: `{ "snapshot_date": "YYYY-MM-DD", "gists": [{"id": "...", "title": "...", "last_active": "..."}] }`. Future runs diff against `gists[]` and report `last_active` as the date column.
