#!/bin/bash
# Updates caddy routes, metadata, and guest hostname following a container rename.
_rename_vps_post_config() {
  local old_name="$1" new_name="$2" was_running="$3"
  if [ -f "/etc/caddy/vpsforge/${old_name}.caddy" ]; then
    mv "/etc/caddy/vpsforge/${old_name}.caddy" "/etc/caddy/vpsforge/${new_name}.caddy"
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  fi
  sync_vps_metadata "$new_name"

  # Synchronize hostname and /etc/hosts inside the guest container
  if [ "$was_running" -eq 1 ]; then
    echo "Restarting $new_name..."
    incus start "$new_name" >/dev/null 2>&1 || true
    wait_ready "$new_name" || true
    set_guest_hostname "$new_name" "$old_name"
  else
    # Briefly start to synchronize hostname, then stop so it remains in STOPPED state
    incus start "$new_name" >/dev/null 2>&1 || true
    wait_ready "$new_name" || true
    set_guest_hostname "$new_name" "$old_name"
    incus stop "$new_name" --force >/dev/null 2>&1 || true
  fi
}
