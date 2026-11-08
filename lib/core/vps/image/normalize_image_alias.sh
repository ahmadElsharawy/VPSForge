#!/bin/bash
normalize_image_alias() {
  local img="${1:-}"
  if [[ "$img" =~ ^images:ubuntu/([0-9]+\.[0-9]+)/minimal$ ]]; then
    echo "images:ubuntu/${BASH_REMATCH[1]}"
  else
    echo "$img"
  fi
}
