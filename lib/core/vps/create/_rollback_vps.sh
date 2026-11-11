#!/bin/bash
# Forcibly delete an incomplete VPS during creation rollback.
_rollback_vps() {
  local name="$1"
  echo "Deleting incomplete VPS..."
  incus delete "$name" --force >/dev/null 2>&1 || true
}
