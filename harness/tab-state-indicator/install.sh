#!/usr/bin/env bash
# Install tab-state-indicator: copies scripts to ~/.claude/scripts/, merges
# hook entries into ~/.claude/settings.json, sets statusLine.
#
# Idempotent: safe to re-run. Identifies its own entries by the sentinel
# tag "mutwo:tab-state-indicator" prefixed to each hook command.
#
# Safety: validates settings.json JSON before AND after merge. Backs up to a
# timestamped file. If post-merge validation fails, restores backup.

set -euo pipefail

MOD_NAME="tab-state-indicator"
SENTINEL="mutwo:${MOD_NAME}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"
SCRIPTS_DIR="$HOME/.claude/scripts"
TARGET_STATE="$SCRIPTS_DIR/claude-state.sh"
TARGET_STATUS="$SCRIPTS_DIR/claude-statusline.sh"

# --- Dependency checks ---------------------------------------------------
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required. Install via: brew install jq" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python3 is required (used for JSON validation)" >&2; exit 1; }

# --- Pre-merge validation ------------------------------------------------
mkdir -p "$SCRIPTS_DIR" "$(dirname "$SETTINGS")"
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
  echo "Created empty $SETTINGS"
fi
if ! python3 -c "import json,sys; json.load(open('$SETTINGS'))" 2>/dev/null; then
  echo "FATAL: $SETTINGS is not valid JSON. Fix it manually before installing." >&2
  exit 1
fi

# --- Backup --------------------------------------------------------------
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$SETTINGS.bak.$TS"
cp "$SETTINGS" "$BACKUP"
echo "Backed up settings.json to: $BACKUP"

# --- Build proposed new settings ----------------------------------------
STATE_CMD=": $SENTINEL; $TARGET_STATE"
STATUS_CMD="$TARGET_STATUS"

NEW_SETTINGS=$(jq \
  --arg working_cmd "$STATE_CMD working" \
  --arg idle_cmd "$STATE_CMD idle" \
  --arg status_cmd "$STATUS_CMD" \
  --arg sentinel "$SENTINEL" \
  '
    # Remove any prior tab-state-indicator entries before re-adding (idempotency).
    .hooks //= {}
    | .hooks.UserPromptSubmit = (((.hooks.UserPromptSubmit // []) | map(select((.hooks // []) | map(.command // "") | any(contains($sentinel)) | not))) + [{matcher: "", hooks: [{type: "command", command: $working_cmd}]}])
    | .hooks.PostToolUse     = (((.hooks.PostToolUse     // []) | map(select((.hooks // []) | map(.command // "") | any(contains($sentinel)) | not))) + [{matcher: "", hooks: [{type: "command", command: $working_cmd}]}])
    | .hooks.Stop            = (((.hooks.Stop            // []) | map(select((.hooks // []) | map(.command // "") | any(contains($sentinel)) | not))) + [{matcher: "", hooks: [{type: "command", command: $idle_cmd}]}])
    | .hooks.Notification    = (((.hooks.Notification    // []) | map(select((.hooks // []) | map(.command // "") | any(contains($sentinel)) | not))) + [{matcher: "", hooks: [{type: "command", command: $idle_cmd}]}])
    # AskUserQuestion notifications: fire idle on PreToolUse for that tool only,
    # so the user gets a banner showing the question itself the moment Claude
    # invokes it. Notification-hook does not fire for AskUserQuestion in
    # current Claude Code, so this is the only path that catches AUQ.
    | .hooks.PreToolUse      = (((.hooks.PreToolUse      // []) | map(select((.hooks // []) | map(.command // "") | any(contains($sentinel)) | not))) + [{matcher: "AskUserQuestion", hooks: [{type: "command", command: $idle_cmd}]}])
    # statusLine cleanup: only delete if it is an object whose command matches
    # ours. The type guard prevents jq from erroring out on a malformed
    # settings.json where .statusLine is a non-object value.
    | (
        if ((.statusLine // {}) | type) == "object" and (.statusLine.command // "") == $status_cmd
        then del(.statusLine)
        else .
        end
      )
    # Suppress Claude Code native banner so the custom osascript notification
    # is the only one. Only set if unset, to respect existing user preference.
    # Track ownership in a .mutwo namespace so uninstall can distinguish
    # "we set it" from "user already had this value before install". Type-guard
    # .mutwo writes too, so a non-object .mutwo (set by someone else or
    # malformed) does not crash the installer; in that case we set the
    # preferredNotifChannel but skip the ownership flag, so uninstall will
    # conservatively leave preferredNotifChannel alone.
    | (
        if has("preferredNotifChannel") | not
        then .preferredNotifChannel = "notifications_disabled"
             | (
                 if ((.mutwo // {}) | type) == "object"
                 then .mutwo = ((.mutwo // {}) + {tab_state_indicator_set_preferred_notif: true})
                 else .
                 end
               )
        else .
        end
      )
  ' "$SETTINGS")

# --- Diff preview --------------------------------------------------------
TMP_NEW=$(mktemp)
printf '%s\n' "$NEW_SETTINGS" > "$TMP_NEW"

echo ""
echo "=== Proposed changes to settings.json ==="
diff -u "$SETTINGS" "$TMP_NEW" || true
echo "==========================================="
echo ""

# --- Confirm -------------------------------------------------------------
if [ "${MUTWO_YES:-}" != "1" ]; then
  read -r -p "Apply these changes? [y/N] " ANSWER
  case "$ANSWER" in
    y|Y|yes|YES) ;;
    *) echo "Aborted. Backup at $BACKUP retained."; rm -f "$TMP_NEW"; exit 1 ;;
  esac
fi

# --- Apply ---------------------------------------------------------------
mv "$TMP_NEW" "$SETTINGS"

# --- Post-merge validation ----------------------------------------------
if ! python3 -c "import json,sys; json.load(open('$SETTINGS'))" 2>/dev/null; then
  echo "FATAL: post-merge JSON is invalid. Restoring backup." >&2
  cp "$BACKUP" "$SETTINGS"
  exit 1
fi

# --- Copy scripts -------------------------------------------------------
cp "$HERE/scripts/claude-state.sh" "$TARGET_STATE"
chmod +x "$TARGET_STATE"

# Clean up stale statusline script from older versions, if present.
rm -f "$TARGET_STATUS"

echo ""
echo "Installed $MOD_NAME."
echo "  Scripts:  $TARGET_STATE"
echo "  Settings: $SETTINGS (sentinel: $SENTINEL)"
echo "  Backup:   $BACKUP"
echo ""
echo "Restart Claude Code or start a fresh session to activate the hooks."
