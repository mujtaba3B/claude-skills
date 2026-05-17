# tab-state-indicator

Turns each Claude Code iTerm2 tab a different color based on what the session is doing, so you can tell at a glance which one needs you across multiple parallel sessions.

- 🟢 **Working**: tab tinted green. Claude is processing your input or running tools.
- 🔴 **Needs you**: tab tinted red. Claude has finished its turn (or is waiting on a permission prompt) and your input is required.

Also shows a 🟢/🔴 badge in the top-right of the pane and a status-line summary of the last assistant message at the bottom.

## Requirements

- macOS
- iTerm2 (any recent version with OSC escape sequence support)
- `jq` and `python3` on PATH

## Install

```bash
cd harness/tab-state-indicator
./install.sh
```

The installer:

1. Validates your existing `~/.claude/settings.json` is valid JSON.
2. Backs it up to `~/.claude/settings.json.bak.<timestamp>`.
3. Shows you a unified diff of the proposed changes.
4. Waits for `y/N` confirmation.
5. Merges in the hook entries (tagged with `mutwo:tab-state-indicator`), sets the `statusLine`, copies two scripts to `~/.claude/scripts/`.
6. Re-validates JSON; auto-restores backup if anything went wrong.

Pass `MUTWO_YES=1 ./install.sh` to skip the confirmation prompt (use for scripted installs).

## Uninstall

```bash
./uninstall.sh
```

Removes only the hook entries it owns (identified by the sentinel `mutwo:tab-state-indicator` inside each command). Any other hooks you have in `settings.json` are preserved. Also clears `statusLine` if it still points at our script.

## How it works

- Four hooks: `UserPromptSubmit` and `PostToolUse` flip state to working (green); `Stop` and `Notification` flip state to idle (red).
- Each hook runs a small shell script that walks up the process tree to find the iTerm2 pty, then writes iTerm2 escape sequences (`OSC 6` for tab color, `OSC 1337;SetBadgeFormat` for the badge) directly to that pty.
- The status line is a separate shell script that reads a per-session JSON state file written by the hooks. It prints the latest assistant message text, truncated to 240 chars.
- State files live in `~/.claude/state/<session_id>.json` and `<session_id>.tty`. Files older than 30 days are auto-cleaned on each hook fire.

## Caveats

- iTerm2 only. If you run Claude Code inside tmux or over SSH, the tty discovery silently no-ops. (Future: tmux passthrough.)
- The tab color change is your primary signal. If you have very narrow split panes, the badge text wraps; consider a single-emoji badge (default already 🔴/🟢).
- Background-pane color is NOT changed (too jarring for reading text). Only the tab chrome and a badge overlay.
