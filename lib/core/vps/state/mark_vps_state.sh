#!/bin/bash
# Mark a VPS with an unfinished-operation state (creating / importing / cloning ...),
# or clear it with an empty value. The marker also records which process owns the
# operation, so startup recovery only cleans up VPSs whose owner has really died
# (never one that is being created right now by another process).
#   mark_vps_state <name> <state|"">
mark_vps_state() {
  local name="${1:?name}" state="${2:-}" start
  if [ -n "$state" ]; then
    start=$(sed 's/^.*) //' "/proc/$$/stat" 2>/dev/null | awk '{print $20}')
    incus config set "$name" user.vpsforge.state "$state" >/dev/null 2>&1 || true
    incus config set "$name" user.vpsforge.state_owner "$$:$start" >/dev/null 2>&1 || true
  else
    incus config unset "$name" user.vpsforge.state >/dev/null 2>&1 || true
    incus config unset "$name" user.vpsforge.state_owner >/dev/null 2>&1 || true
  fi
}
