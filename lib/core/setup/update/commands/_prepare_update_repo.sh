#!/bin/bash
# Ensure update repository exists, stashes uncommitted changes, backs up unpushed commits, and fetches remotes.
#   _prepare_update_repo <repo_dir> <repo_url>
_prepare_update_repo() {
  local repo_dir="$1" repo_url="$2"

  # 1. Ensure repository exists
  if [ ! -d "$repo_dir/.git" ]; then
    echo "Cloning canonical repository from $repo_url..."
    mkdir -p "$(dirname "$repo_dir")"
    rm -rf "$repo_dir"
    if ! git clone "$repo_url" "$repo_dir"; then
      echo "ERROR: Failed to clone repository from $repo_url." >&2
      return 1
    fi
  fi

  # 2. Check for uncommitted changes in repo working tree
  if [ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null || true)" ]; then
    local stash_name="vpsforge-auto-stash-$(date +%Y%m%d_%H%M%S)"
    echo "WARNING: Uncommitted changes detected in $repo_dir."
    echo "Saving changes safely to Git stash ($stash_name)..."
    git -C "$repo_dir" stash push -u -m "$stash_name" >/dev/null 2>&1 || true
  fi

  # 3. Check for local unpushed commits and back them up
  local unpushed
  unpushed=$(git -C "$repo_dir" rev-list --count '@{u}..HEAD' 2>/dev/null || true)
  [[ "$unpushed" =~ ^[0-9]+$ ]] || unpushed=0
  if [ "$unpushed" -gt 0 ]; then
    local backup_branch="backup-local-$(date +%Y%m%d_%H%M%S)"
    echo "Notice: $unpushed local commit(s) found. Creating backup branch '$backup_branch'..."
    git -C "$repo_dir" branch -f "$backup_branch" HEAD 2>/dev/null || true
  fi

  # 4. Fetch all remote branches and tags
  echo "Fetching latest tags and commits from origin..."
  # Unshallow if it was a shallow clone
  if [ -f "$repo_dir/.git/shallow" ]; then
    git -C "$repo_dir" fetch --unshallow --all --tags >/dev/null 2>&1 || true
  fi
  git -C "$repo_dir" fetch --all --tags --prune --force >/dev/null 2>&1 || {
    echo "WARNING: Fetch failed or network unavailable; checking local repository objects..."
  }
}
