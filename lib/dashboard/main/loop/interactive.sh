#!/bin/bash
# Runs the main interactive terminal dashboard loop.
interactive() {
  printf "\033[?1049h"
  trap 'printf "\033[?1049l"' EXIT
  trap 'exit 130' INT TERM

  local c is_refresh=0 INPUT_BUFFER="" char status
  load_settings
  repair_pool_quotas   # disk limits work and the dashboard shows real usage

  while :; do
    if [ "$is_refresh" -eq 1 ]; then
      dashboard refresh
    elif [ -z "$INPUT_BUFFER" ]; then
      dashboard full
    fi
    is_refresh=0

    status=0
    _interactive_read_key "$([ -n "$INPUT_BUFFER" ] && echo 1 || echo 0)" || status=$?
    [ "$status" -eq 2 ] && { get_network_info; get_public_ip; is_refresh=1; continue; }
    [ "$status" -ne 0 ] && return 0
    char="$INTERACTIVE_KEY"

    status=0
    _interactive_handle_key "$char" || status=$?
    [ "$status" -eq 2 ] && { get_network_info; get_public_ip; is_refresh=1; continue; }
    [ "$status" -ne 0 ] && continue
    c="$INTERACTIVE_SUBMITTED"

    status=0
    _interactive_dispatch "$c" || status=$?
    if [ "$status" -eq 15 ]; then
      printf "\033[?1049l"; echo "Goodbye!"; return 0 2>/dev/null || exit 0
    elif [ "$status" -eq 2 ]; then
      is_refresh=1
    fi
  done
}
