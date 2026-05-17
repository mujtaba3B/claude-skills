#!/usr/bin/env bash
# Self-contained tests for cleanup-branches.sh.
# Builds throwaway git repos in $TMPDIR, runs the script, asserts behavior.
# Exit 0 on success; non-zero on first failed assertion.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/cleanup-branches.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# Per-test git identity in env so each subshell inherits it without polluting
# the user's global config.
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=t@e
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=t@e

mkrepo() {
  # Creates an "upstream" bare repo and a local clone with `main` initialized.
  # Echoes the local clone path.
  local root upstream local
  root="$(mktemp -d)"
  upstream="$root/upstream.git"
  local="$root/local"
  git init --quiet --bare -b main "$upstream"
  git init --quiet -b main "$local"
  ( cd "$local"
    git remote add origin "$upstream"
    echo "hello" > README.md
    git add README.md
    git commit --quiet -m "init"
    git push --quiet -u origin main
  )
  echo "$local"
}

# --------------------------------------------------------------------
# Test 1: a merged feature branch on a non-current branch is deleted.
# --------------------------------------------------------------------
test_merged_branch_deleted() {
  local repo
  repo="$(mkrepo)"
  cd "$repo"

  git checkout --quiet -b feat/done
  echo "x" > a.txt && git add a.txt && git commit --quiet -m "feat"
  git checkout --quiet main
  git merge --quiet --no-ff feat/done -m "merge feat/done"
  git push --quiet origin main

  out="$(bash "$SCRIPT" "$repo" 2>&1)"
  echo "$out" | grep -q "DELETED feat/done" \
    || fail "expected DELETED feat/done. got: $out"
  git show-ref --verify --quiet refs/heads/feat/done \
    && fail "feat/done still exists after cleanup"
  pass "test_merged_branch_deleted"
}

# --------------------------------------------------------------------
# Test 2: an unmerged branch is kept.
# --------------------------------------------------------------------
test_unmerged_branch_kept() {
  local repo
  repo="$(mkrepo)"
  cd "$repo"

  git checkout --quiet -b feat/wip
  echo "y" > b.txt && git add b.txt && git commit --quiet -m "wip"
  git checkout --quiet main

  out="$(bash "$SCRIPT" "$repo" 2>&1)" || true
  echo "$out" | grep -q "DELETED feat/wip" \
    && fail "feat/wip should not have been deleted. got: $out"
  git show-ref --verify --quiet refs/heads/feat/wip \
    || fail "feat/wip was unexpectedly deleted"
  pass "test_unmerged_branch_kept"
}

# --------------------------------------------------------------------
# Test 3: switches off a merged branch you're currently on, then deletes it.
# --------------------------------------------------------------------
test_switch_off_current_then_delete() {
  local repo
  repo="$(mkrepo)"
  cd "$repo"

  git checkout --quiet -b feat/shipped
  echo "z" > c.txt && git add c.txt && git commit --quiet -m "ship"
  git checkout --quiet main
  git merge --quiet --no-ff feat/shipped -m "merge feat/shipped"
  git push --quiet origin main
  git checkout --quiet feat/shipped

  out="$(bash "$SCRIPT" "$repo" 2>&1)"
  echo "$out" | grep -q "DELETED feat/shipped" \
    || fail "expected DELETED feat/shipped. got: $out"
  on="$(git symbolic-ref --short HEAD)"
  [[ "$on" == "main" ]] || fail "expected HEAD on main after delete, got $on"
  pass "test_switch_off_current_then_delete"
}

# --------------------------------------------------------------------
# Test 4: dirty current branch (about to be deleted) is kept; cleanup of
# OTHER branches proceeds.
# --------------------------------------------------------------------
test_dirty_current_kept_others_cleaned() {
  local repo
  repo="$(mkrepo)"
  cd "$repo"

  # Merged branch 1, on which we're sitting and have uncommitted work.
  git checkout --quiet -b feat/messy
  echo "m" > m.txt && git add m.txt && git commit --quiet -m "merged work"
  git checkout --quiet main
  git merge --quiet --no-ff feat/messy -m "merge feat/messy"
  git push --quiet origin main

  # Merged branch 2 (clean, not current). Should still be deleted.
  git checkout --quiet -b feat/other
  echo "o" > o.txt && git add o.txt && git commit --quiet -m "other"
  git checkout --quiet main
  git merge --quiet --no-ff feat/other -m "merge feat/other"
  git push --quiet origin main

  # Switch onto feat/messy and dirty the worktree.
  git checkout --quiet feat/messy
  echo "dirty" >> m.txt

  out="$(bash "$SCRIPT" "$repo" 2>&1)"
  echo "$out" | grep -q "KEPT-current (feat/messy)" \
    || fail "expected KEPT-current note. got: $out"
  echo "$out" | grep -q "DELETED feat/other" \
    || fail "expected DELETED feat/other. got: $out"
  git show-ref --verify --quiet refs/heads/feat/messy \
    || fail "feat/messy should still exist (was dirty)"
  pass "test_dirty_current_kept_others_cleaned"
}

# --------------------------------------------------------------------
# Test 5: PROTECT_BRANCHES is honored.
# --------------------------------------------------------------------
test_protect_branches_honored() {
  local repo
  repo="$(mkrepo)"
  cd "$repo"

  git checkout --quiet -b release/keep
  echo "r" > r.txt && git add r.txt && git commit --quiet -m "r"
  git checkout --quiet main
  git merge --quiet --no-ff release/keep -m "merge release/keep"
  git push --quiet origin main

  out="$(PROTECT_BRANCHES=release/keep bash "$SCRIPT" "$repo" 2>&1)"
  echo "$out" | grep -q "DELETED release/keep" \
    && fail "release/keep should have been protected. got: $out"
  git show-ref --verify --quiet refs/heads/release/keep \
    || fail "release/keep was deleted despite PROTECT_BRANCHES"
  pass "test_protect_branches_honored"
}

# --------------------------------------------------------------------
# Test 6: dry-run does not change anything.
# --------------------------------------------------------------------
test_dry_run_no_changes() {
  local repo
  repo="$(mkrepo)"
  cd "$repo"

  git checkout --quiet -b feat/dry
  echo "d" > d.txt && git add d.txt && git commit --quiet -m "d"
  git checkout --quiet main
  git merge --quiet --no-ff feat/dry -m "merge feat/dry"
  git push --quiet origin main

  out="$(CLEANUP_DRY_RUN=1 bash "$SCRIPT" "$repo" 2>&1)"
  echo "$out" | grep -q "DRY: would delete feat/dry" \
    || fail "expected DRY note. got: $out"
  git show-ref --verify --quiet refs/heads/feat/dry \
    || fail "feat/dry was deleted during dry run"
  pass "test_dry_run_no_changes"
}

# --------------------------------------------------------------------
# Test 7: no candidates -> exit 0, friendly message.
# --------------------------------------------------------------------
test_no_candidates() {
  local repo
  repo="$(mkrepo)"
  cd "$repo"

  out="$(bash "$SCRIPT" "$repo" 2>&1)"
  echo "$out" | grep -q "nothing to clean" \
    || fail "expected 'nothing to clean'. got: $out"
  pass "test_no_candidates"
}

test_merged_branch_deleted
test_unmerged_branch_kept
test_switch_off_current_then_delete
test_dirty_current_kept_others_cleaned
test_protect_branches_honored
test_dry_run_no_changes
test_no_candidates

echo "ALL TESTS PASSED"
