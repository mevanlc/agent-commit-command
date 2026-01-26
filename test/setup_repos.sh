#!/usr/bin/env bash
# setup_repos.sh - Create test repositories for commit-tool testing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="${SCRIPT_DIR}/repos"

rm -rf "$REPOS_DIR"
mkdir -p "$REPOS_DIR"

# Helper to create a basic repo with a commit
create_repo() {
  local name="$1"
  local dir="${REPOS_DIR}/${name}"
  mkdir -p "$dir"
  cd "$dir"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  echo "initial" > file.txt
  git add file.txt
  git commit -q -m "Initial commit"
}

# === STAGING SCENARIOS ===

# clean-workdir: nothing to commit
create_repo "clean-workdir"

# only-staged: only staged changes
create_repo "only-staged"
cd "${REPOS_DIR}/only-staged"
echo "staged change" > staged.txt
git add staged.txt

# only-unstaged: only unstaged changes (modified tracked file)
create_repo "only-unstaged"
cd "${REPOS_DIR}/only-unstaged"
echo "modified" >> file.txt

# staged-and-unstaged: both staged and unstaged
create_repo "staged-and-unstaged"
cd "${REPOS_DIR}/staged-and-unstaged"
echo "staged" > staged.txt
git add staged.txt
echo "unstaged" >> file.txt

# nothing-staged: has unstaged, but nothing staged
create_repo "nothing-staged"
cd "${REPOS_DIR}/nothing-staged"
echo "unstaged only" >> file.txt

# === IDENTITY WARNING SCENARIOS ===

# name-mismatch: same email, different name in history
create_repo "name-mismatch"
cd "${REPOS_DIR}/name-mismatch"
git config user.name "Different Name"
# Current config will be "Different Name" but history has "Test User" with same email

# multiple-ids: multiple configured IDs have commits
mkdir -p "${REPOS_DIR}/multiple-ids"
cd "${REPOS_DIR}/multiple-ids"
git init -q
git config user.name "Alice"
git config user.email "alice@example.com"
echo "alice" > file.txt
git add file.txt
git commit -q -m "Alice's commit"
git config user.name "Bob"
git config user.email "bob@example.com"
echo "bob" >> file.txt
git add file.txt
git commit -q -m "Bob's commit"
# Now set to Alice, so we have commits from both configured IDs

# === SPECIAL GIT STATES ===

# detached-head: detached HEAD state
create_repo "detached-head"
cd "${REPOS_DIR}/detached-head"
echo "second" > second.txt
git add second.txt
git commit -q -m "Second commit"
git checkout -q HEAD~1

# merge-in-progress: merge conflict
create_repo "merge-in-progress"
cd "${REPOS_DIR}/merge-in-progress"
git checkout -q -b feature
echo "feature change" > file.txt
git add file.txt
git commit -q -m "Feature commit"
git checkout -q main
echo "main change" > file.txt
git add file.txt
git commit -q -m "Main commit"
git merge feature --no-commit 2>/dev/null || true

# rebase-in-progress: rebase conflict
create_repo "rebase-in-progress"
cd "${REPOS_DIR}/rebase-in-progress"
git checkout -q -b feature
echo "feature" > file.txt
git add file.txt
git commit -q -m "Feature"
git checkout -q main
echo "main" > file.txt
git add file.txt
git commit -q -m "Main"
git checkout -q feature
git rebase main 2>/dev/null || true

# === ERROR CASES ===

# not-a-repo: just a directory, not a git repo
mkdir -p "${REPOS_DIR}/not-a-repo"
echo "not a repo" > "${REPOS_DIR}/not-a-repo/file.txt"

# malformed-repo: corrupted git directory
create_repo "malformed-repo"
cd "${REPOS_DIR}/malformed-repo"
rm -rf .git/objects/*

echo "Test repos created in ${REPOS_DIR}"
