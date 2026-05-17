#!/usr/bin/env bash
# Delete local branches that have already been merged into origin/main
# (or origin/master) and switch the working tree back to that base branch.
#
# Safety rules:
#   - Only deletes LOCAL branches. Never pushes branch deletions to a remote.
#   - Uses `git branch -D`, but only on branches that the prior
#     `git branch --merged <base>` step has already confirmed are reachable
#     from base. -d would refuse here because it checks merged-into-HEAD,
#     which is wrong when we're sitting on a different feature branch.
#   - Skips deletion when the working tree is dirty or there are unpushed
#     commits on the current branch.
#   - Never touches the base branch itself, HEAD, or any branch passed
#     in PROTECT_BRANCHES (comma-separated env var).
#   - When the user is currently ON a branch that's about to be deleted,
#     checks out the base branch first.
#
# Usage:
#   cleanup-branches.sh [<repo-path>]
#     <repo-path> defaults to $(pwd).
#
# Env:
#   CLEANUP_DRY_RUN=1     -> print what would happen, change nothing
#   PROTECT_BRANCHES=a,b  -> additional branches to never delete
#   BASE_BRANCH=main      -> override base (otherwise auto-detected)
#
# Output: one log line per branch action (DELETED / SKIPPED / KEPT-current).
# Exit 0 even if nothing was cleaned up; non-zero only on hard errors.
set -euo pipefail

repo="${1:-$(pwd)}"
cd "$repo"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "cleanup-branches: not a git repo: $repo" >&2
  exit 1
fi

DRY="${CLEANUP_DRY_RUN:-0}"
PROTECT_EXTRA="${PROTECT_BRANCHES:-}"

# Detect base branch: explicit override > origin/HEAD symref > main > master.
detect_base() {
  if [[ -n "${BASE_BRANCH:-}" ]]; then echo "$BASE_BRANCH"; return; fi
  local ref
  ref="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$ref" ]]; then echo "${ref##refs/remotes/origin/}"; return; fi
  if git show-ref --verify --quiet refs/heads/main; then echo main; return; fi
  if git show-ref --verify --quiet refs/heads/master; then echo master; return; fi
  echo ""
}

base="$(detect_base)"
if [[ -z "$base" ]]; then
  echo "cleanup-branches: could not detect base branch (no main/master/origin HEAD)" >&2
  exit 1
fi

# Fetch + prune so "merged into origin/<base>" reflects reality. Tolerate
# offline / no-remote repos: missing origin is not fatal.
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --prune origin >/dev/null 2>&1 || true
fi

# Pick the ref we'll measure "merged" against. Prefer origin/<base> (catches
# PRs merged on GitHub even if local <base> is stale); fall back to local.
merged_into="origin/$base"
git rev-parse --verify --quiet "$merged_into" >/dev/null 2>&1 || merged_into="$base"

current="$(git symbolic-ref --short -q HEAD || echo "")"

# Build the protect set as a newline-delimited string (bash 3.2 compatible:
# no `declare -A`).
protect_list="$base"
if [[ -n "$PROTECT_EXTRA" ]]; then
  oldIFS="$IFS"; IFS=','
  for b in $PROTECT_EXTRA; do
    b="${b// /}"
    [[ -n "$b" ]] && protect_list="$protect_list
$b"
  done
  IFS="$oldIFS"
fi

is_protected() {
  printf '%s\n' "$protect_list" | grep -Fxq "$1"
}

# Collect candidate branches: local branches whose tip is reachable from
# the merged-into ref, minus protected ones. `git branch --merged` prints
# with a leading "* " for the current branch and "+ " for branches checked
# out in a worktree; strip those.
candidates_raw="$(
  git branch --merged "$merged_into" --format='%(refname:short)' \
    | sed 's/^[*+] //' \
    | awk 'NF'
)"

to_delete=()
while IFS= read -r b; do
  [[ -z "$b" ]] && continue
  is_protected "$b" && continue
  to_delete+=("$b")
done <<<"$candidates_raw"

if [[ ${#to_delete[@]} -eq 0 ]]; then
  echo "cleanup-branches: nothing to clean (base=$base)"
  exit 0
fi

# Safety: refuse to switch off current branch if working tree is dirty
# or has unpushed commits. Without that, we could strand work.
dirty_or_ahead() {
  if [[ -n "$(git status --porcelain)" ]]; then return 0; fi
  if [[ -n "$current" ]] && git rev-parse --verify --quiet "@{u}" >/dev/null 2>&1; then
    local ahead
    ahead="$(git rev-list --count '@{u}..HEAD')"
    [[ "$ahead" != "0" ]] && return 0
  fi
  return 1
}

need_switch=0
for b in "${to_delete[@]}"; do
  [[ "$b" == "$current" ]] && need_switch=1
done

if [[ "$need_switch" == "1" ]] && dirty_or_ahead; then
  echo "cleanup-branches: KEPT-current ($current) has uncommitted or unpushed work; skipping all deletes that would require checkout"
  # Remove the current branch from to_delete so we still clean the rest.
  filtered=()
  for b in "${to_delete[@]}"; do
    [[ "$b" != "$current" ]] && filtered+=("$b")
  done
  # bash 3.2 + set -u: empty-array expansion needs the +alt form.
  to_delete=("${filtered[@]+"${filtered[@]}"}")
  need_switch=0
fi

if [[ "$need_switch" == "1" ]]; then
  if [[ "$DRY" == "1" ]]; then
    echo "DRY: would checkout $base"
  else
    git checkout "$base" >/dev/null 2>&1
    if git remote get-url origin >/dev/null 2>&1; then
      git pull --ff-only origin "$base" >/dev/null 2>&1 || true
    fi
  fi
fi

for b in "${to_delete[@]}"; do
  if [[ "$DRY" == "1" ]]; then
    echo "DRY: would delete $b"
    continue
  fi
  if git branch -D "$b" >/dev/null 2>&1; then
    echo "DELETED $b"
  else
    echo "SKIPPED $b (in use by a worktree or refused by git)"
  fi
done

echo "cleanup-branches: done (base=$base, on=$(git symbolic-ref --short -q HEAD || echo detached))"
