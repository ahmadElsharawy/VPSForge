#!/bin/bash
# Run a test command and record a pass or failure.
ok() { local n="$1"; shift; if "$@" >>"$LOG" 2>&1; then PASS=$((PASS+1)); echo "PASS  $n"; else FAILN=$((FAILN+1)); echo "FAIL  $n"; tail -4 "$LOG" | sed 's/^/        /'; fi; }
