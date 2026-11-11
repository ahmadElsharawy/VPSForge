#!/bin/bash
# Refresh system binary symlinks and the vpsforge-update CLI wrapper.
#   _refresh_install_symlinks <app_dir>
_refresh_install_symlinks() {
  local app_dir="${1:?app_dir}"
  mkdir -p /usr/local/bin
  ln -sf "$app_dir/vpsforge.sh" /usr/local/bin/vpsforge
  ln -sf "$app_dir/vpsforge.sh" /usr/local/bin/VPSForge
  ln -sf "$app_dir/vpsforge.sh" /usr/local/bin/VPSFORGE

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
  chmod 755 /usr/local/bin/vpsforge-update
}
