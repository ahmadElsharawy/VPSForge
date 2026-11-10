#!/bin/bash
# Make an exact copy of a VPS (files, installed software, settings) under a new name,
# with its own IP and SSH port. On BTRFS the copy is instant and shares unchanged data,
# so it costs almost no extra disk. Great for experiments: clone, break the clone, delete it.
# Guarded: if it fails or is stopped, nothing of the copy is left behind.
#   clone_vps <source> <new_name>
clone_vps() {
  local src="${1:-}" new="${2:-}" num ip port
  incus info "$src" >/dev/null 2>&1 || { echo "ERROR: VPS '$src' does not exist."; return 1; }
  if ! is_valid_vps_name "$new"; then
    echo "ERROR: Invalid name '$new'. Use letters, digits and dashes only (no dots, underscores or spaces; not only digits; no dash at the start or end)."
    return 1
  fi
  incus info "$new" >/dev/null 2>&1 && { echo "ERROR: A VPS named '$new' already exists."; return 1; }

  num=$(next_num)
  ip="${NETWORK_PREFIX}.$((IP_START + num - 1))"
  port=$(vps_fixed_port "$num")

  if vps_inventory 2>/dev/null | awk -F'|' -v ip="$ip" '$2 == ip { f = 1 } END { exit !f }'; then
    echo "ERROR: the address $ip is already used by another VPS. Nothing was cloned."
    return 1
  fi

  run_guarded "cleanup_failed_vps $new $ip $port" _clone_vps_steps "$src" "$new" "$num" "$ip" "$port"
}
