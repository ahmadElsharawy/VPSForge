#!/bin/bash
set -euo pipefail

APP_DIR="/opt/vpsforge"
DEFAULT_REPO="https://github.com/ahmadElsharawy/VPSForge.git"

if [ "$EUID" -ne 0 ]; then exec sudo -E bash "$0" "$@"; fi

apt-get update
apt-get install -y curl git

mkdir -p "$APP_DIR"

# Detect if running from local directory containing vpsforge.sh
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi

if [ -z "${VPSFORGE_REPO_URL:-}" ] && [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/vpsforge.sh" ]; then
  echo "Installing VPSForge from local directory..."
  cp "$SCRIPT_DIR/vpsforge.sh" "$APP_DIR/vpsforge.sh"
  rm -rf "$APP_DIR/lib"
  cp -r "$SCRIPT_DIR/lib" "$APP_DIR/lib"
else
  REPO_URL="${VPSFORGE_REPO_URL:-$DEFAULT_REPO}"
  echo "Cloning and installing VPSForge from $REPO_URL..."
  rm -rf "$APP_DIR/repo"
  git clone --depth 1 "$REPO_URL" "$APP_DIR/repo"
  cp "$APP_DIR/repo/vpsforge.sh" "$APP_DIR/vpsforge.sh"
  rm -rf "$APP_DIR/lib"
  cp -r "$APP_DIR/repo/lib" "$APP_DIR/lib"
fi

chmod +x "$APP_DIR/vpsforge.sh"
chmod +x "$APP_DIR/lib"/*.sh 2>/dev/null || true

ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/vpsforge
ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/VPSForge
ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/VPSFORGE

cat > /usr/local/bin/vpsforge-update <<'UPD'
#!/bin/bash
# Thin wrapper: all update/rollback logic lives in vpsforge.sh
set -euo pipefail
APP="/opt/vpsforge/vpsforge.sh"
[ -x "$APP" ] || { echo "VPSForge is not installed at $APP."; exit 1; }

case "${1:-}" in
  --list|-l) exec "$APP" update --list ;;
  "")        exec "$APP" update latest ;;
  *)         exec "$APP" update "$1" ;;
esac
UPD
chmod +x /usr/local/bin/vpsforge-update

echo "================================================"
echo " VPSForge installed successfully."
echo " Run: VPSForge"
echo "================================================"
