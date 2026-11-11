#!/bin/bash
# Resolve an image name or alias to a prioritized, deduplicated list of candidate image remotes.
resolve_image_candidates() {
  local raw="${1:-images:ubuntu/noble}"
  local clean="$raw" candidate
  local -a candidate_list=("$raw")
  local -A seen=()

  clean="${clean#images:}"
  clean="${clean#ubuntu:}"

  while IFS= read -r candidate; do
    [ -n "$candidate" ] && candidate_list+=("$candidate")
  done < <(_image_alias_candidates "$raw" "$clean")

  for candidate in "${candidate_list[@]}"; do
    if [ -z "${seen[$candidate]:-}" ]; then
      seen[$candidate]=1
      echo "$candidate"
    fi
  done
}
