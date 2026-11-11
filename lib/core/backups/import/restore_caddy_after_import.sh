#!/bin/bash
# If an import stopped while it was changing Caddy (for example while taking a domain over from another VPS),
# put every Caddy file back exactly as it was before the import started.
#   restore_caddy_after_import <target_name>
restore_caddy_after_import() {
  local target="${1:?target}" dir="/opt/vpsforge/.import-caddy-${target}"
  [ -d "$dir" ] || return 0
  rm -f "$CADDY_CONF_DIR"/*.caddy
  cp -a "$dir"/. "$CADDY_CONF_DIR"/ 2>/dev/null || true
  systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  rm -rf "$dir"
  return 0
}
