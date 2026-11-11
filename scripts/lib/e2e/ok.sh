#!/bin/bash
# Run a test command and log pass/fail status with output tail on failure.
ok() {
  local name="$1"; shift
  if "$@" >>"$LOG" 2>&1; then PASS=$((PASS+1)); echo "PASS  $name"
  else FAILN=$((FAILN+1)); echo "FAIL  $name"; tail -4 "$LOG" | sed 's/^/        /'; fi
}
