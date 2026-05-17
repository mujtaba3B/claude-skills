#!/usr/bin/env bash
# Uninstall tab-state-indicator: removes hook entries tagged with the
# "mutwo:tab-state-indicator" sentinel from ~/.claude/settings.json, clears
# our statusLine if it still points at our script, and removes the scripts
# from ~/.claude/scripts/.
#
# Location-independent: identifies entries by sentinel, not by file path.

set -euo pipefail

MOD_NAME="tab-state-indicator"
SENTINEL="mutwo:${MOD_NAME}"
SETTINGS="$HOME/.claude/settings.json"
SCRIPTS_DIR="$HOME/.claude/scripts"
TARGET_STATE="$SCRIPTS_DIR/claude-state.sh"
TARGET_STATUS="$SCRIPTS_DIR/claude-statusline.sh"

command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python3 is required" >&2; exit 1; }

[ -f "$SETTINGS" ] || { echo "No settings.json at $SETTINGS; nothing to uninstall."; exit 0; }

if ! python3 -c "import json,sys; json.load(open('$SETTINGS'))" 2>/dev/null; then
  echo "FATAL: $SETTINGS is not valid JSON. Fix it manually before uninstalling." >&2
  exit 1
fi

TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$SETTINGS.bak.$TS"
cp "$SETTINGS" "$BACKUP"
echo "Backed up settings.json to: $BACKUP"

NEW_SETTINGS=$(jq \
  --arg sentinel "$SENTINEL" \
  --arg status_path "$TARGET_STATUS" \
  '
    # Strip any hook entries containing the sentinel; drop empty event arrays after.
    .hooks //= {}
    | .hooks |= with_entries(
        .value |= (
          map(select((.hooks // []) | map(.command // "") | any(contains($sentinel)) | not))
        )
      )
    | .hooks |= with_entries(select(.value | length > 0))
    # Remove statusLine only if it is still ours.
    | if (.statusLine.command // "") == $status_path then del(.statusLine) else . end
  ' "$SETTINGS")

TMP_NEW=$(mktemp)
printf '%s\n' "$NEW_SETTINGS" > "$TMP_NEW"

echo ""
echo "=== Proposed removal from settings.json ==="
diff -u "$SETTINGS" "$TMP_NEW" || true
echo "==========================================="
echo ""

if [ "${MUTWO_YES:-}" != "1" ]; then
  read -r -p "Apply these changes? [y/N] " ANSWER
  case "$ANSWER" in
    y|Y|yes|YES) ;;
    *) echo "Aborted. Backup at $BACKUP retained."; rm -f "$TMP_NEW"; exit 1 ;;
  esac
fi

mv "$TMP_NEW" "$SETTINGS"

if ! python3 -c "import json,sys; json.load(open('$SETTINGS'))" 2>/dev/null; then
  echo "FATAL: post-uninstall JSON is invalid. Restoring backup." >&2
  cp "$BACKUP" "$SETTINGS"
  exit 1
fi

# Remove the scripts (only if they exist; not strictly required, but tidy).
rm -f "$TARGET_STATE" "$TARGET_STATUS"

echo ""
echo "Uninstalled $MOD_NAME."
echo "  Settings: $SETTINGS"
echo "  Backup:   $BACKUP"
echo "  Removed:  $TARGET_STATE, $TARGET_STATUS"
