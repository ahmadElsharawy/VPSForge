#!/bin/bash
# Generate candidate remote image names for a given raw image string and cleaned alias.
_image_alias_candidates() {
  local raw="$1" clean="$2"
  case "$clean" in
    24.04|ubuntu/24.04|noble|ubuntu/noble)
      printf '%s\n' "images:ubuntu/noble" "images:ubuntu/24.04" "ubuntu:24.04" "ubuntu:noble" "images:ubuntu/noble/cloud"
      ;;
    22.04|ubuntu/22.04|jammy|ubuntu/jammy)
      printf '%s\n' "images:ubuntu/jammy" "images:ubuntu/22.04" "ubuntu:22.04" "ubuntu:jammy" "images:ubuntu/jammy/cloud"
      ;;
    20.04|ubuntu/20.04|focal|ubuntu/focal)
      printf '%s\n' "images:ubuntu/focal" "images:ubuntu/20.04" "ubuntu:20.04" "ubuntu:focal"
      ;;
    18.04|ubuntu/18.04|bionic|ubuntu/bionic)
      printf '%s\n' "images:ubuntu/bionic" "images:ubuntu/18.04" "ubuntu:18.04" "ubuntu:bionic"
      ;;
    *)
      if [[ "$raw" != images:* ]] && [[ "$raw" != ubuntu:* ]]; then
        printf '%s\n' "images:$raw" "ubuntu:$raw"
      fi
      ;;
  esac

  case "$clean" in
    ubuntu/*|noble|jammy|focal|bionic|24.04|22.04|20.04|18.04)
      printf '%s\n' "images:ubuntu/noble" "images:ubuntu/jammy" "images:ubuntu/24.04" "ubuntu:24.04" "ubuntu:noble"
      ;;
  esac
}
