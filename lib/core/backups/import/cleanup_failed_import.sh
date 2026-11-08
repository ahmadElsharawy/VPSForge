#!/bin/bash
# Remove a VPS that an import left half-made (instance, IP, port, firewall, proxy config).
#   cleanup_failed_import <target_name> [reason]
cleanup_failed_import() {
  local target="${1:?target}" ip="" port=""
  if incus info "$target" >/dev/null 2>&1; then
    ip=$(incus config get "$target" user.vpsforge.ip 2>/dev/null || true)
    port=$(incus config get "$target" user.vpsforge.ssh_port 2>/dev/null || true)
  fi
  cleanup_failed_vps "$target" "$ip" "$port" "${2:-}"
}
