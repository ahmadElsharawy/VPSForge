#!/bin/bash
# Create binary symlinks in PATH and the vpsforge-update CLI wrapper.
_ensure_setup_bin_links() {
  local app_script="${VPSFORGE_SCRIPT_DIR:-/opt/vpsforge}/vpsforge.sh"
  if [ -f "$app_script" ]; then
    mkdir -p /usr/local/bin
    ln -sf "$app_script" /usr/local/bin/vpsforge 2>/dev/null || true
    ln -sf "$app_script" /usr/local/bin/VPSForge 2>/dev/null || true
    ln -sf "$app_script" /usr/local/bin/VPSFORGE 2>/dev/null || true
    chmod 755 "$app_script" 2>/dev/null || true

    cat > /usr/local/bin/vpsforge-update <<'UPD_WRAPPER'
#!/bin/bash
set -euo pipefail
APP="/opt/vpsforge/vpsforge.sh"
if [ ! -x "$APP" ]; then
  APP="$(command -v vpsforge 2>/dev/null || echo "")"
fi
[ -n "$APP" ] && [ -x "$APP" ] || { echo "ERROR: VPSForge executable not found."; exit 1; }
exec "$APP" update "$@"
UPD_WRAPPER
    chmod 755 /usr/local/bin/vpsforge-update 2>/dev/null || true
  fi
}
