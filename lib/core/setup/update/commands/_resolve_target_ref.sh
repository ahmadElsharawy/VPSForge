#!/bin/bash
# Resolve git target version, branch, tag or commit hash into a commit SHA.
#   _resolve_target_ref <repo_dir> <target>
_resolve_target_ref() {
  local repo_dir="$1" target="$2"
  local target_sha=""

  if [ "$target" = "latest" ] || [ -z "$target" ] || [ "$target" = "main" ]; then
    # Default: latest commit on origin/main or origin/HEAD
    target_sha=$(git -C "$repo_dir" rev-parse origin/main 2>/dev/null || git -C "$repo_dir" rev-parse origin/HEAD 2>/dev/null || git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)
  elif git -C "$repo_dir" rev-parse "refs/tags/$target" >/dev/null 2>&1; then
    target_sha=$(git -C "$repo_dir" rev-parse "refs/tags/$target^{commit}" 2>/dev/null || true)
  elif git -C "$repo_dir" rev-parse "origin/$target" >/dev/null 2>&1; then
    target_sha=$(git -C "$repo_dir" rev-parse "origin/$target^{commit}" 2>/dev/null || true)
  else
    target_sha=$(git -C "$repo_dir" rev-parse "$target^{commit}" 2>/dev/null || true)
  fi

  echo "$target_sha"
}
