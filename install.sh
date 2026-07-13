#!/bin/bash
set -euo pipefail
APP_DIR="/opt/vpsforge"
REPO_URL="${VPSFORGE_REPO_URL:-}"
if [ "$EUID" -ne 0 ]; then exec sudo -E bash "$0" "$@"; fi
apt-get update
apt-get install -y curl git
mkdir -p "$APP_DIR"
if [ -n "$REPO_URL" ]; then
  rm -rf "$APP_DIR/repo"
  git clone --depth 1 "$REPO_URL" "$APP_DIR/repo"
  cp "$APP_DIR/repo/vpsforge.sh" "$APP_DIR/vpsforge.sh"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cp "$SCRIPT_DIR/vpsforge.sh" "$APP_DIR/vpsforge.sh"
fi
chmod +x "$APP_DIR/vpsforge.sh"
ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/vpsforge
ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/VPSForge
ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/VPSFORGE
cat > /usr/local/bin/vpsforge-update <<'UPD'
#!/bin/bash
# Thin wrapper: all update/rollback logic lives in vpsforge.sh
# (apply_update_version / update_list_versions), so the CLI tool and the
# interactive "Settings -> Update / Change Version" menu never fall out of
# sync with each other.
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
echo "VPSForge installed successfully. Run: VPSForge"
