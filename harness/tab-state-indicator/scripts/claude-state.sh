#!/bin/bash
# Sets iTerm2 tab color + badge + user var to reflect Claude Code state.
# Usage: claude-state.sh <working|idle>
# Reads hook event JSON from stdin to extract session_id and transcript_path.

set -u

JQ_BIN=$(/usr/bin/command -v jq 2>/dev/null || true)
[ -n "$JQ_BIN" ] || { echo "claude-state.sh: jq is required but not installed" >&2; exit 0; }

STATE="${1:-idle}"
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"

# State file TTL cleanup: drop entries older than 30 days. Cheap, runs once per hook fire.
find "$STATE_DIR" -type f \( -name '*.json' -o -name '*.tty' \) -mtime +30 -delete 2>/dev/null || true

INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
HOOK_EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
HOOK_MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // empty' 2>/dev/null)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
# Stop hook payload includes the just-finished assistant turn directly. Prefer
# this over tailing the transcript file, because the transcript JSONL is not
# flushed until after the Stop hook returns, so a tail-based read produces the
# previous turn's text.
LAST_ASSISTANT=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)

# AskUserQuestion-specific: extract the first question text so the notification
# body can show what's being asked. PreToolUse on the AskUserQuestion matcher
# fires before the question dialog blocks the model, which is when we want to
# notify the user.
QUESTION_TEXT=""
if [ "$HOOK_EVENT" = "PreToolUse" ] && [ "$TOOL_NAME" = "AskUserQuestion" ]; then
  QUESTION_TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.questions[0].question // empty' 2>/dev/null)
fi

if [ -z "$SESSION_ID" ]; then
  SESSION_ID="unknown-$$"
fi

# If the Stop hook fires while a Claude-managed background bash shell is still
# running for this session, keep the tab green. Claude Code writes one JSON file
# per live session into ~/.claude/sessions/<pid>.json with a `status` field; the
# value `"shell"` means at least one background shell is outstanding (this is
# the same signal that drives Claude Code's own "N shell still running" UI).
# Fail open: if the file is missing, malformed, or the field has an unexpected
# value, behave as before (flip to idle). This signal is undocumented; if it
# ever drifts, a one-time warning lands in notification-trace.log.
#
# Timing note: Claude Code flips status from "busy" to "shell" AFTER the Stop
# hook returns, not before. A naive single read at hook-fire time always sees
# "busy". Poll briefly (100ms ticks, up to ~600ms total) so we can observe the
# transition. Break early on "shell" (override to green) or on any settled
# non-busy value (let today's idle flow run).
if [ "$STATE" = "idle" ] && [ "$HOOK_EVENT" = "Stop" ]; then
  SESSIONS_DIR="$HOME/.claude/sessions"
  if [ -d "$SESSIONS_DIR" ]; then
    for _ in 1 2 3 4 5 6; do
      SESS_STATUS=$("$JQ_BIN" -r --arg sid "$SESSION_ID" '
        select(.sessionId == $sid) | .status // empty
      ' "$SESSIONS_DIR"/*.json 2>/dev/null | head -1)
      if [ "$SESS_STATUS" = "shell" ]; then
        STATE="working"
        break
      fi
      if [ -n "$SESS_STATUS" ] && [ "$SESS_STATUS" != "busy" ]; then
        break
      fi
      sleep 0.1
    done
  fi
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

# Build a 1-line SUMMARY of the most recent assistant text.
#
# Priority order:
#   1. last_assistant_message from the hook payload (Stop hook only). This is
#      the just-finished turn's text and is the only source guaranteed to be
#      current at hook-fire time.
#   2. Transcript JSONL tail, walking back to find the most recent assistant
#      message with text content. Used by non-Stop events (UserPromptSubmit,
#      PostToolUse, PreToolUse, Notification), where last_assistant_message
#      is not provided.
#
# Both sources are passed through the same trim: extract the final paragraph
# (everything after the last blank line), collapse internal whitespace, then
# cap at 500 chars.
RAW_SUMMARY=""
if [ -n "$LAST_ASSISTANT" ]; then
  RAW_SUMMARY="$LAST_ASSISTANT"
elif [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  RAW_SUMMARY=$(tail -r "$TRANSCRIPT" 2>/dev/null | head -500 | \
    jq -rs '
      map(select(.type == "assistant"))
      | map(
          .message.content
          | if type == "array"
            then (map(select(.type == "text")) | .[-1].text // "")
            else (. // "")
            end
        )
      | map(select(. != ""))
      | .[0] // empty
    ' 2>/dev/null)
fi

SUMMARY=""
if [ -n "$RAW_SUMMARY" ]; then
  # Extract the last paragraph (everything after the final blank line), then
  # collapse internal whitespace and cap at 500 chars. macOS truncates the
  # banner to ~3 visual lines anyway, but the expanded view in Notification
  # Center will show the full body up to this cap.
  SUMMARY=$(printf '%s' "$RAW_SUMMARY" | awk '
    BEGIN { RS = "\n[[:space:]]*\n"; last = "" }
    { if ($0 ~ /[^[:space:]]/) last = $0 }
    END { print last }
  ' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ //; s/ $//' | head -c 500)
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

# macOS notification when state flips to red (idle). Body and title vary by
# hook event so the user sees the most useful copy for each case:
#   PreToolUse + AskUserQuestion -> the question itself
#   Stop (turn end) -> last assistant text (from payload or transcript)
#   Notification with "waiting for your input" message -> SUPPRESSED. This is
#     Claude Code's idle reminder, which duplicates the Stop banner that
#     already fired. Tab color and badge still update.
#   Notification with any other message (permission prompts, etc.) -> fires
#     with the hook's message as the body, so the user knows Claude is
#     blocked on something actionable.
IS_IDLE_REMINDER=0
if [ "$HOOK_EVENT" = "Notification" ] && \
   printf '%s' "$HOOK_MESSAGE" | grep -qi 'waiting for your input'; then
  IS_IDLE_REMINDER=1
fi
if [ "$STATE" = "idle" ] && [ "$IS_IDLE_REMINDER" = "0" ]; then
  NOTIF_TITLE=""
  NOTIF_BODY=""
  if [ -n "$QUESTION_TEXT" ]; then
    NOTIF_TITLE="❓ Claude needs an answer"
    NOTIF_BODY="$QUESTION_TEXT"
  elif [ "$HOOK_EVENT" = "Notification" ] && [ -n "$HOOK_MESSAGE" ]; then
    NOTIF_TITLE="🔴 Claude has stopped working"
    NOTIF_BODY="$HOOK_MESSAGE"
  else
    NOTIF_TITLE="🔴 Claude has stopped working"
    NOTIF_BODY="${SUMMARY:-waiting on you}"
  fi
  esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
  BODY_ESC=$(esc "$NOTIF_BODY")
  TITLE_ESC=$(esc "$NOTIF_TITLE")
  osascript -e "display notification \"$BODY_ESC\" with title \"$TITLE_ESC\" sound name \"Pop\"" >/dev/null 2>&1 || true
fi

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
