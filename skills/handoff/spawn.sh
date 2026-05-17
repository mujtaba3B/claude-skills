#!/usr/bin/env bash
# Spawn a new iTerm2 vertical split running `claude` with a preloaded prompt.
# Reads the prompt from a file (avoids argv size and shell-quoting issues).
# Usage: spawn.sh <prompt-file>
set -euo pipefail

file="${1:-}"
if [[ -z "$file" || ! -f "$file" ]]; then
  echo "usage: spawn.sh <prompt-file>" >&2
  exit 1
fi

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

PROMPT="$(cat "$file")"
CWD="$(pwd)"

# iTerm2's `split vertically with default profile command "..."` execs the command
# directly without a shell, so compound commands (cd, &&, ;, |) need /bin/bash -c
# wrapping or the new pane closes instantly.
CWD="$CWD" PROMPT="$PROMPT" CLAUDE_BIN="$CLAUDE_BIN" CLAUDE_EXTRA_ARGS="$CLAUDE_EXTRA_ARGS" osascript <<'APPLESCRIPT'
set cwd to system attribute "CWD"
set userPrompt to system attribute "PROMPT"
set claudeBin to system attribute "CLAUDE_BIN"
set claudeExtraArgs to system attribute "CLAUDE_EXTRA_ARGS"
set innerCmd to "cd " & quoted form of cwd & " && exec " & quoted form of claudeBin
if claudeExtraArgs is not "" then
  set innerCmd to innerCmd & " " & claudeExtraArgs
end if
set innerCmd to innerCmd & " " & quoted form of userPrompt
tell application "iTerm"
  tell current window
    set invokingSession to current session
    tell invokingSession
      split vertically with default profile command ("/bin/bash -c " & quoted form of innerCmd)
    end tell
  end tell
end tell
APPLESCRIPT

echo "Spawned new iTerm pane."
