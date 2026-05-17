# tab-state-indicator

Turns each Claude Code iTerm2 tab a different color based on what the session is doing, so you can tell at a glance which one needs you across multiple parallel sessions.

- 🟢 **Working**: tab tinted green. Claude is processing your input or running tools.
- 🔴 **Needs you**: tab tinted red, a 🟢/🔴 badge in the top-right of the pane, AND a macOS notification fires. Title and body adapt to what's pending:
  - `🔴 Claude has stopped working` + last assistant message (turn-end)
  - `🔴 Claude has stopped working` + Claude Code's prompt text (permission prompts)
  - `❓ Claude needs an answer` + the question itself (when Claude invokes `AskUserQuestion`)

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
5. Merges in the hook entries (tagged with `mutwo:tab-state-indicator`) and copies `claude-state.sh` to `~/.claude/scripts/`.
6. Re-validates JSON; auto-restores backup if anything went wrong.

Pass `MUTWO_YES=1 ./install.sh` to skip the confirmation prompt (use for scripted installs).

## Uninstall

```bash
./uninstall.sh
```

Removes only the hook entries it owns (identified by the sentinel `mutwo:tab-state-indicator` inside each command). Any other hooks you have in `settings.json` are preserved. Also clears any stale `statusLine` left over from earlier versions of this module that pointed at our script. Removes `preferredNotifChannel` only if the installer set it (tracked via a `.mutwo.tab_state_indicator_set_preferred_notif` ownership flag), so a user who already had `notifications_disabled` configured before installing keeps that preference. Cleans up an empty `.mutwo` namespace if it would be left behind.

## How it works

- Five hooks: `UserPromptSubmit` and `PostToolUse` flip state to working (green); `Stop` and `Notification` flip state to idle (red); `PreToolUse` with matcher `AskUserQuestion` also flips to idle so the question itself shows in the notification.
- Each hook runs a small shell script that walks up the process tree to find the iTerm2 pty, then writes iTerm2 escape sequences (`OSC 6` for tab color, `OSC 1337;SetBadgeFormat` for the badge) directly to that pty.
- On idle, the same script fires a macOS notification via `osascript`. Body source depends on the hook event: the question text from `tool_input.questions[0].question` for `PreToolUse`-hook events on `AskUserQuestion`, the hook input's `message` field for `Notification`-hook events (mid-turn permission prompts), or the last assistant text in the transcript for `Stop`-hook events.
- The installer also sets `preferredNotifChannel: "notifications_disabled"` (only if that key is not already present in `settings.json`, so existing user preferences are preserved) so Claude Code's own native banner does not duplicate the custom one. Re-installing on an older version that set a `statusLine` will clear that stale entry.
- State files live in `~/.claude/state/<session_id>.json` and `<session_id>.tty`. Files older than 30 days are auto-cleaned on each hook fire.

## Caveats

- iTerm2 only. If you run Claude Code inside tmux or over SSH, the tty discovery silently no-ops. (Future: tmux passthrough.)
- The tab color change is your primary signal. If you have very narrow split panes, the badge text wraps; consider a single-emoji badge (default already 🔴/🟢).
- Background-pane color is NOT changed (too jarring for reading text). Only the tab chrome and a badge overlay.
