#!/bin/bash
# Assert that a test command fails.
no() {
  local name="$1"; shift
  if "$@" >>"$LOG" 2>&1; then FAILN=$((FAILN+1)); echo "FAIL  $name (expected failure)"
  else PASS=$((PASS+1)); echo "PASS  $name"; fi
}
