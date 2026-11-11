#!/bin/bash
# Run a command expected to fail and record a pass when it fails.
no() { local n="$1"; shift; if "$@" >>"$LOG" 2>&1; then FAILN=$((FAILN+1)); echo "FAIL  $n (expected failure)"; else PASS=$((PASS+1)); echo "PASS  $n"; fi; }
