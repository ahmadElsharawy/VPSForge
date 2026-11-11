#!/bin/bash
# Reads a single key from standard input with timeout support for auto-refresh.
_interactive_read_key() {
  local has_buf="$1"
  local read_rc=0
  INTERACTIVE_KEY=""
  if [ "$AUTO_REFRESH" = "on" ] && [ "$has_buf" -eq 0 ]; then
    read -s -n 1 -t "$REFRESH_INTERVAL" INTERACTIVE_KEY || read_rc=$?
    if [ "$read_rc" -gt 128 ]; then
      return 2  # timeout
    elif [ "$read_rc" -ne 0 ]; then
      return 1  # EOF
    fi
  else
    read -s -n 1 INTERACTIVE_KEY || return 1
  fi
  return 0
}
