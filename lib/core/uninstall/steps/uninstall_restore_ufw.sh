#!/bin/bash
# Remove the ufw rules for ports 80/443 that VPSForge added (skip any that existed before).
uninstall_restore_ufw() {
  local port
  command -v ufw >/dev/null 2>&1 || return 0
  [ -f "$PRE_INSTALL_DIR/ufw.status" ] || return 0
  grep -q "Status: active" "$PRE_INSTALL_DIR/ufw.status" || return 0
  for port in 80 443; do
    if ! grep -qE "^${port}/tcp[[:space:]]+ALLOW" "$PRE_INSTALL_DIR/ufw.status"; then
      uninstall_run ufw delete allow "${port}/tcp"
    fi
  done
}
