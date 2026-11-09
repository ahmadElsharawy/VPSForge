#!/bin/bash
# Undo hold_vps_for_replace after a failed import: the original VPS comes back as it was.
#   restore_replaced_vps <name> <hold_name> <caddy_backup_file>
restore_replaced_vps() {
  local name="${1:?name}" hold="${2:?hold name}" caddy_bak="${3:-}"
  incus info "$hold" >/dev/null 2>&1 || return 0
  incus rename "$hold" "$name" >/dev/null 2>&1 || return 1
  if [ -n "$caddy_bak" ] && [ -f "$caddy_bak" ]; then
    mv -f "$caddy_bak" "$CADDY_CONF_DIR/${name}.caddy"
  fi
  incus start "$name" >/dev/null 2>&1 || true
  echo "The original '$name' was put back unchanged."
}
