#!/bin/bash
resolve_image_candidates() {
  local raw="${1:-images:ubuntu/noble}"
  local -a list=()
  local clean="$raw"

  clean="${clean#images:}"
  clean="${clean#ubuntu:}"

  list+=("$raw")

  case "$clean" in
    24.04|ubuntu/24.04|noble|ubuntu/noble)
      list+=("images:ubuntu/noble" "images:ubuntu/24.04" "ubuntu:24.04" "ubuntu:noble" "images:ubuntu/noble/cloud")
      ;;
    22.04|ubuntu/22.04|jammy|ubuntu/jammy)
      list+=("images:ubuntu/jammy" "images:ubuntu/22.04" "ubuntu:22.04" "ubuntu:jammy" "images:ubuntu/jammy/cloud")
      ;;
    20.04|ubuntu/20.04|focal|ubuntu/focal)
      list+=("images:ubuntu/focal" "images:ubuntu/20.04" "ubuntu:20.04" "ubuntu:focal")
      ;;
    18.04|ubuntu/18.04|bionic|ubuntu/bionic)
      list+=("images:ubuntu/bionic" "images:ubuntu/18.04" "ubuntu:18.04" "ubuntu:bionic")
      ;;
    *)
      if [[ "$raw" != images:* ]] && [[ "$raw" != ubuntu:* ]]; then
        list+=("images:$raw" "ubuntu:$raw")
      fi
      ;;
  esac

  # Fall back to Ubuntu only when Ubuntu was requested (never swap a Debian/Alpine choice for Ubuntu).
  case "$clean" in
    ubuntu/*|noble|jammy|focal|bionic|24.04|22.04|20.04|18.04)
      list+=("images:ubuntu/noble" "images:ubuntu/jammy" "images:ubuntu/24.04" "ubuntu:24.04" "ubuntu:noble")
      ;;
  esac

  local -A seen=()
  local c
  for c in "${list[@]}"; do
    if [ -z "${seen[$c]:-}" ]; then
      seen[$c]=1
      echo "$c"
    fi
  done
}
