#!/bin/bash
# Sets iTerm2 tab color + badge + user var to reflect Claude Code state.
# Usage: claude-state.sh <working|idle>
# Reads hook event JSON from stdin to extract session_id and transcript_path.

set -u

command -v jq >/dev/null 2>&1 || { echo "claude-state.sh: jq is required but not installed" >&2; exit 0; }

STATE="${1:-idle}"
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"

# State file TTL cleanup: drop entries older than 30 days. Cheap, runs once per hook fire.
find "$STATE_DIR" -type f \( -name '*.json' -o -name '*.tty' \) -mtime +30 -delete 2>/dev/null || true

INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -z "$SESSION_ID" ]; then
  SESSION_ID="unknown-$$"
fi

TTY_FILE="$STATE_DIR/$SESSION_ID.tty"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"

# Discover the iTerm2 tab's tty by walking up the process tree until we find one.
discover_tty() {
  local pid=$PPID
  local tty
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$tty" ] && [ "$tty" != "??" ] && [ "$tty" != "?" ]; then
      echo "/dev/$tty"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ]; then
      break
    fi
  done
  return 1
}

TTY=""
if [ -f "$TTY_FILE" ]; then
  TTY=$(cat "$TTY_FILE")
  [ -e "$TTY" ] || TTY=""
fi
if [ -z "$TTY" ]; then
  TTY=$(discover_tty || true)
  [ -n "$TTY" ] && echo "$TTY" > "$TTY_FILE"
fi

# Pull the latest assistant text from the transcript for a 1-line summary.
SUMMARY=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  SUMMARY=$(tail -r "$TRANSCRIPT" 2>/dev/null | head -200 | \
    jq -rs 'map(select(.type == "assistant")) | .[0].message.content
            | if type == "array" then
                map(select(.type == "text")) | .[0].text // empty
              else . end' 2>/dev/null | \
    tr '\n' ' ' | sed 's/  */ /g' | head -c 240)
fi

# Pick visuals.
case "$STATE" in
  working)
    R=0; G=180; B=60
    EMOJI="🟢"
    ;;
  idle|blocked|*)
    R=255; G=0; B=0
    EMOJI="🔴"
    STATE="idle"
    ;;
esac

# Write state file (read by the statusline script).
cat > "$STATE_FILE" <<EOF
{"state":"$STATE","emoji":"$EMOJI","summary":$(printf '%s' "$SUMMARY" | jq -Rs .),"updated_at":"$(date -u +%FT%TZ)"}
EOF

# Emit iTerm2 escapes if we have a tty.
if [ -n "$TTY" ] && [ -w "$TTY" ]; then
  {
    printf '\033]6;1;bg;red;brightness;%d\a' "$R"
    printf '\033]6;1;bg;green;brightness;%d\a' "$G"
    printf '\033]6;1;bg;blue;brightness;%d\a' "$B"
    BADGE_B64=$(printf '%s' "$EMOJI" | base64)
    printf '\033]1337;SetBadgeFormat=%s\a' "$BADGE_B64"
    USERVAR_B64=$(printf '%s' "$EMOJI" | base64)
    printf '\033]1337;SetUserVar=claudeState=%s\a' "$USERVAR_B64"
  } > "$TTY" 2>/dev/null
fi

exit 0
