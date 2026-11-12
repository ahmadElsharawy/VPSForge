#!/bin/bash
# A reinstall keeps the original VPS aside (named <vps>-old-reinstall) until the new one is complete.
# If it never finished: delete the half-made new VPS and restore the original exactly as it was.
# If it did finish: just delete the leftover original.
#   recover_interrupted_reinstall <old_name> <original_name>
recover_interrupted_reinstall() {
  local old="${1:?old}" original="${2:-}" ip port new_state=""
  [ -n "$original" ] || return 0

  if incus info "$original" >/dev/null 2>&1; then
    new_state=$(incus config get "$original" user.vpsforge.state 2>/dev/null || true)
    if [ -z "$new_state" ]; then
      echo "Recovery: reinstall of '$original' had finished; removing the old copy."
      incus delete "$old" --force >/dev/null 2>&1 || true
      reclaim_pool_space
      return 0
    fi
    ip=$(incus config get "$old" user.vpsforge.ip 2>/dev/null || true)
    port=$(incus config get "$old" user.vpsforge.ssh_port 2>/dev/null || true)
    # The half-made new VPS has the original's name, IP and Caddy file name: keep the original's
    # port-forwards and website file (they come back with it below).
    VPS_KEEP_FORWARDS=1 cleanup_failed_vps "$original" "" ""
  fi

  echo "Recovery: the reinstall of '$original' did not finish. Restoring the original VPS..."
  ip=$(incus config get "$old" user.vpsforge.ip 2>/dev/null || true)
  port=$(incus config get "$old" user.vpsforge.ssh_port 2>/dev/null || true)
  if incus rename "$old" "$original" >/dev/null 2>&1; then
    mark_vps_state "$original" ""
    incus config unset "$original" user.vpsforge.reinstall_of >/dev/null 2>&1 || true
    incus start "$original" >/dev/null 2>&1 || true
    [ -n "$ip" ] && [ -n "$port" ] && vps_ssh_forward_enabled "$original" && add_forward_rule "$ip" "$port" >/dev/null 2>&1
    echo "Recovery: '$original' is back, unchanged."
  else
    echo "Recovery: could not rename '$old' back to '$original'. It is still intact under the name '$old'."
  fi
}
