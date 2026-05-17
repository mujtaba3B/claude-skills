#!/bin/bash
# Claude Code status line: prints a 1-line context summary of the latest assistant turn.
# State (working/idle) is already conveyed by tab color + badge emoji, so this line is
# pure context, not state.

set -u

command -v jq >/dev/null 2>&1 || { printf 'jq required for claude-statusline.sh'; exit 0; }

INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
STATE_FILE="$HOME/.claude/state/$SESSION_ID.json"

SUMMARY=""
if [ -f "$STATE_FILE" ]; then
  SUMMARY=$(jq -r '.summary // ""' "$STATE_FILE" 2>/dev/null)
fi

# Fallback: read transcript directly if state file has no summary yet.
if [ -z "$SUMMARY" ]; then
  TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    SUMMARY=$(tail -r "$TRANSCRIPT" 2>/dev/null | head -200 | \
      jq -rs 'map(select(.type == "assistant")) | .[0].message.content
              | if type == "array" then
                  map(select(.type == "text")) | .[0].text // empty
                else . end' 2>/dev/null | \
      tr '\n' ' ' | sed 's/  */ /g')
  fi
fi

if [ -z "$SUMMARY" ]; then
  printf 'starting...'
else
  printf '%s' "$SUMMARY" | head -c 240
fi
