#!/bin/bash
# Run at every start: finish cleaning up anything an earlier run left half-done
# (power cut, kill -9, closed SSH session). Silent when there is nothing to do.
#   - a VPS marked creating / importing  -> removed completely (disk, IP, port, firewall)
#   - an original VPS set aside by a reinstall that never finished -> put back as it was
#   - half-written backup files, stale firewall rules
recover_interrupted_operations() {
  local name state owner ip port original
  local -a names=()
  mapfile -t names < <(incus list -c n --format csv 2>/dev/null | grep -v '^$')

  for name in "${names[@]}"; do
    state=$(incus config get "$name" user.vpsforge.state 2>/dev/null || true)
    [ -n "$state" ] || continue
    owner=$(incus config get "$name" user.vpsforge.state_owner 2>/dev/null || true)
    # Still being worked on by a live VPSForge process (for example a creation running in another terminal)? Leave it.
    vps_state_owner_alive "$owner" && continue
    case "$state" in
      creating|importing|cloning)
        ip=$(incus config get "$name" user.vpsforge.ip 2>/dev/null || true)
        port=$(incus config get "$name" user.vpsforge.ssh_port 2>/dev/null || true)
        echo "Recovery: '$name' was left unfinished by an interrupted $state. Removing it completely..."
        cleanup_failed_vps "$name" "$ip" "$port"
        echo "Recovery: '$name' removed, everything it reserved was released."
        ;;
      reinstall-old)
        original=$(incus config get "$name" user.vpsforge.reinstall_of 2>/dev/null || true)
        recover_interrupted_reinstall "$name" "$original"
        ;;
    esac
  done

  clean_stale_temp_backups >/dev/null 2>&1 || true
  sweep_stale_forward_rules
  return 0
}
