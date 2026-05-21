#!/usr/bin/env bash
# Spawn a new iTerm2 vertical split running `claude` with a preloaded prompt.
# Reads the prompt from a file (avoids argv size and shell-quoting issues).
# Usage: spawn.sh <prompt-file> [<cwd-override>]
#
# CWD resolution order (first match wins):
#   1. <cwd-override> argument
#   2. HANDOFF_CWD environment variable
#   3. "default_cwd" in <skill-dir>/settings.json
#   4. "default_cwd" in <skill-dir>/settings.example.json
#   5. caller's $(pwd)
# Leading "~" in the resolved path is expanded to $HOME.
set -euo pipefail

file="${1:-}"
cwd_override="${2:-}"
if [[ -z "$file" || ! -f "$file" ]]; then
  echo "usage: spawn.sh <prompt-file> [<cwd-override>]" >&2
  exit 1
fi

SKILL_DIR="$(cd "$(dirname "$0")" && pwd -P)"

read_default_cwd() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  sed -n 's/.*"default_cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -n1
}

resolve_cwd() {
  local v=""
  if [[ -n "$cwd_override" ]]; then
    v="$cwd_override"
  elif [[ -n "${HANDOFF_CWD:-}" ]]; then
    v="$HANDOFF_CWD"
  else
    v="$(read_default_cwd "$SKILL_DIR/settings.json" || true)"
    [[ -z "$v" ]] && v="$(read_default_cwd "$SKILL_DIR/settings.example.json" || true)"
  fi
  [[ -z "$v" ]] && v="$(pwd)"
  # Quote ~ in parameter expansion to suppress bash's tilde expansion on the pattern.
  if [[ "$v" == "~" ]]; then
    v="$HOME"
  elif [[ "$v" == "~/"* ]]; then
    v="$HOME/${v#"~/"}"
  fi
  echo "$v"
}

CLAUDE_BIN="$(command -v claude || true)"
if [[ -z "$CLAUDE_BIN" ]]; then
  echo "claude not found in PATH" >&2
  exit 1
fi

# Walk up the process tree looking for --dangerously-skip-permissions on an
# ancestor claude. If found, inherit it onto the new session so a YOLO parent
# spawns YOLO children.
CLAUDE_EXTRA_ARGS=""
pid=$PPID
for _ in 1 2 3 4 5; do
  [[ -z "$pid" || "$pid" == "0" || "$pid" == "1" ]] && break
  cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
  if [[ "$cmd" == *--dangerously-skip-permissions* ]]; then
    CLAUDE_EXTRA_ARGS="--dangerously-skip-permissions"
    break
  fi
  pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ' || true)
done

CWD="$(resolve_cwd)"
if [[ ! -d "$CWD" ]]; then
  echo "handoff: resolved cwd does not exist: $CWD" >&2
  exit 1
fi

# Split with the default profile (no command), so the new session's stored
# launch command is just the user's login shell. Then `write text` the actual
# handoff command into that shell. This matters because iTerm2 copies the
# source session's launch command into any pane created via Cmd+D or right-click
# "Split Vertically" from that session. If we launched claude as the session's
# command, every subsequent manual split in the same window would re-run the
# handoff. Splitting with default profile and typing the command avoids that.
#
# Pass the prompt-file PATH through to AppleScript (not the contents) because
# macOS `system attribute` truncates multi-line env vars at the first newline.
# The shell reads the file at exec time via "$(cat -- ...)" so multi-line
# prompts and shell metacharacters survive intact. The outer double-quotes
# around $(cat ...) make it a single argv to claude; command substitution
# output is not subject to word splitting or glob expansion when quoted.
# The `--` guards against prompt-file paths that begin with `-`.
CWD="$CWD" PROMPT_FILE="$file" CLAUDE_BIN="$CLAUDE_BIN" CLAUDE_EXTRA_ARGS="$CLAUDE_EXTRA_ARGS" osascript <<'APPLESCRIPT'
set cwd to system attribute "CWD"
set promptFile to system attribute "PROMPT_FILE"
set claudeBin to system attribute "CLAUDE_BIN"
set claudeExtraArgs to system attribute "CLAUDE_EXTRA_ARGS"
set innerCmd to "cd " & quoted form of cwd & " && exec " & quoted form of claudeBin
if claudeExtraArgs is not "" then
  set innerCmd to innerCmd & " " & claudeExtraArgs
end if
set innerCmd to innerCmd & " \"$(cat -- " & quoted form of promptFile & ")\""
tell application "iTerm"
  tell current window
    set invokingSession to current session
    tell invokingSession
      set newSession to (split vertically with default profile)
    end tell
    tell newSession
      write text innerCmd
    end tell
  end tell
end tell
APPLESCRIPT

echo "Spawned new iTerm pane."
