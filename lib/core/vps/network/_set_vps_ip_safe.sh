#!/bin/bash
# Apply a device IP to a container, falling back to a restart if live link update fails.
_set_vps_ip_safe() {
  local name="$1" new_ip="$2" old_ip="$3" restart_rc
  if set_vps_device_ip "$name" "$new_ip" >/dev/null 2>&1; then
    return 0
  fi
  if is_vps_running "$name"; then
    incus stop "$name" --force >/dev/null 2>&1 || true
    set_vps_device_ip "$name" "$new_ip" >/dev/null 2>&1
    restart_rc=$?
    incus start "$name" >/dev/null 2>&1 || true
    if [ "$restart_rc" -ne 0 ]; then
      [ -n "$old_ip" ] && set_vps_device_ip "$name" "$old_ip" >/dev/null 2>&1
      echo "ERROR: Incus did not accept $new_ip for $name. Nothing was changed."
      return 1
    fi
    return 0
  fi
  [ -n "$old_ip" ] && set_vps_device_ip "$name" "$old_ip" >/dev/null 2>&1
  echo "ERROR: Incus did not accept $new_ip for $name. Nothing was changed."
  return 1
}
