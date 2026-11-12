#!/bin/bash
# Put the current VPS aside (stopped and renamed) so a backup can replace it safely.
# Nothing is deleted: if the import fails, restore_replaced_vps puts it back.
#   hold_vps_for_replace <name> <hold_name> <caddy_backup_file>
hold_vps_for_replace() {
  local name="${1:?name}" hold="${2:?hold name}" caddy_bak="${3:?caddy backup}"
  incus stop "$name" --force >/dev/null 2>&1 || true
  if ! incus rename "$name" "$hold" >/dev/null 2>&1; then
    incus start "$name" >/dev/null 2>&1 || true
    return 1
  fi
  if [ -f "$CADDY_CONF_DIR/${name}.caddy" ]; then
    mv -f "$CADDY_CONF_DIR/${name}.caddy" "$caddy_bak"
  fi
  return 0
}
