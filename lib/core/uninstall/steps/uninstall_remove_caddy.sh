#!/bin/bash
# Remove VPSForge's reverse-proxy configs and the import line in the Caddyfile.
uninstall_remove_caddy() {
  echo "[5/7] Removing reverse-proxy (Caddy) configs..."
  uninstall_run rm -rf "$CADDY_CONF_DIR"
  if [ -f "$MAIN_CADDYFILE" ] && [ "${UNINSTALL_DRY_RUN:-0}" != "1" ]; then
    sed -i '/^import \/etc\/caddy\/vpsforge\/\*\.caddy$/d' "$MAIN_CADDYFILE" 2>/dev/null || true
    systemctl reload caddy >/dev/null 2>&1 || true
  fi
}
