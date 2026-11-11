#!/bin/bash
# Succeeds when the process that started an operation ("<pid>:<start time>") is still running.
#   vps_state_owner_alive <owner>
vps_state_owner_alive() {
  local owner="${1:-}" pid start now
  [ -n "$owner" ] || return 1
  pid="${owner%%:*}"
  start="${owner#*:}"
  [[ "$pid" =~ ^[0-9]+$ ]] && [ -r "/proc/$pid/stat" ] || return 1
  # field 22 of /proc/<pid>/stat is the start time; strip "pid (name) " first because the name may contain spaces
  now=$(sed 's/^.*) //' "/proc/$pid/stat" 2>/dev/null | awk '{print $20}')
  [ "$now" = "$start" ]
}
