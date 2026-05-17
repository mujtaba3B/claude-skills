#!/usr/bin/env bash
# mutwo installer: interactive picker for skills and harness mods.
#
# - Skills are symlinked from skills/<name>/ into ~/.claude/skills/.
# - Harness mods are installed by running harness/<name>/install.sh.
#
# Idempotent. Re-run anytime to add/refresh skills or install more mods.
#
# Non-interactive:
#   ./install.sh skills          # only install skills
#   ./install.sh harness         # only install harness mods (asks per-mod)
#   ./install.sh all             # skills + every harness mod (with each mod's
#                                # own y/N confirm unless MUTWO_YES=1)

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.claude/skills"
MODE="${1:-}"

install_skills() {
  mkdir -p "$TARGET"
  echo "Installing skills (symlinks into $TARGET)..."
  for skill in "$REPO"/skills/*/; do
    [[ -f "$skill/SKILL.md" ]] || continue
    name="$(basename "$skill")"
    link="$TARGET/$name"
    if [[ -e "$link" && ! -L "$link" ]]; then
      echo "  skip: $link exists and is not a symlink (manual cleanup required)"
      continue
    fi
    ln -sfn "$skill" "$link"
    echo "  linked: $name"
  done
  # Clean stale symlinks pointing into this repo whose targets no longer exist.
  for link in "$TARGET"/*; do
    [[ -L "$link" ]] || continue
    target="$(readlink "$link")"
    case "$target" in
      "$REPO"/*)
        if [[ ! -e "$target" ]]; then
          rm "$link"
          echo "  removed stale: $(basename "$link")"
        fi
        ;;
    esac
  done
}

list_harness_mods() {
  for mod in "$REPO"/harness/*/; do
    [[ -f "$mod/install.sh" ]] || continue
    basename "$mod"
  done
}

install_harness_mod() {
  local name="$1"
  local mod="$REPO/harness/$name"
  if [[ ! -f "$mod/install.sh" ]]; then
    echo "  unknown harness mod: $name" >&2
    return 1
  fi
  echo ""
  echo "=== Installing harness mod: $name ==="
  ( cd "$mod" && bash ./install.sh )
}

install_all_harness() {
  for name in $(list_harness_mods); do
    install_harness_mod "$name"
  done
}

interactive_picker() {
  echo "mutwo installer"
  echo ""
  echo "What do you want to install?"
  echo "  1) Skills only ($(ls -d "$REPO"/skills/*/ 2>/dev/null | wc -l | tr -d ' ') available)"
  echo "  2) Harness mods only ($(list_harness_mods | wc -l | tr -d ' ') available)"
  echo "  3) Everything"
  echo "  4) Pick harness mods individually"
  echo "  q) Quit"
  echo ""
  read -r -p "Choice [1/2/3/4/q]: " CHOICE
  case "$CHOICE" in
    1) install_skills ;;
    2) install_all_harness ;;
    3) install_skills; install_all_harness ;;
    4)
      install_skills
      echo ""
      echo "Available harness mods:"
      i=1
      mods=()
      while IFS= read -r m; do
        mods+=("$m")
        echo "  $i) $m"
        i=$((i + 1))
      done < <(list_harness_mods)
      echo ""
      read -r -p "Enter numbers to install (space-separated), or 'all': " PICKS
      if [ "$PICKS" = "all" ]; then
        install_all_harness
      else
        for n in $PICKS; do
          idx=$((n - 1))
          if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#mods[@]}" ]; then
            install_harness_mod "${mods[$idx]}"
          fi
        done
      fi
      ;;
    q|Q) exit 0 ;;
    *) echo "Unknown choice: $CHOICE" >&2; exit 1 ;;
  esac
}

case "$MODE" in
  skills) install_skills ;;
  harness) install_all_harness ;;
  all) install_skills; install_all_harness ;;
  "") interactive_picker ;;
  *) echo "Usage: $0 [skills|harness|all]" >&2; exit 1 ;;
esac

echo ""
echo "Done. Restart your Claude Code session to pick up new skills/hooks."
