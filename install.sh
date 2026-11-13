#!/bin/bash
set -euo pipefail

APP_DIR="/opt/vpsforge"
DEFAULT_REPO="https://github.com/ahmadElsharawy/VPSForge.git"

if [ "$EUID" -ne 0 ]; then
  if [ ! -f "$0" ]; then
    echo "Please run as root: curl -sSL https://raw.githubusercontent.com/ahmadElsharawy/VPSForge/main/install.sh | sudo bash" >&2
    exit 1
  fi
  exec sudo -E bash "$0" "$@"
fi

# Record how the server looks BEFORE VPSForge touches anything. "vpsforge uninstall"
# uses this to put the server back exactly as it was. (Keep the package list in
# sync with VPSFORGE_PACKAGES in lib/core/common/constants/constants.sh.)
mkdir -p "$APP_DIR"
PRE="$APP_DIR/.pre_install"
if [ ! -d "$PRE" ]; then
  mkdir -p "$PRE"
  command -v iptables-save >/dev/null 2>&1 && iptables-save > "$PRE/iptables.rules" 2>/dev/null || true
  sysctl -n net.ipv4.ip_forward > "$PRE/ip_forward" 2>/dev/null || true
  command -v ufw >/dev/null 2>&1 && ufw status > "$PRE/ufw.status" 2>/dev/null || true
  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | sort > "$PRE/packages_all.txt" || true
  : > "$PRE/packages_present.txt"
  for pkg in incus iptables iptables-persistent netfilter-persistent curl git python3 zstd pigz psmisc btrfs-progs zfsutils-linux zfs-zed caddy; do
    dpkg -s "$pkg" >/dev/null 2>&1 && echo "$pkg" >> "$PRE/packages_present.txt"
  done
  date -u '+%Y-%m-%d %H:%M:%S UTC' > "$PRE/captured_at"
fi

installed_packages() { dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | sort; }

apt-get update
installed_packages > "$PRE/.before_install"
apt-get install -y curl git
installed_packages | comm -13 "$PRE/.before_install" - >> "$PRE/packages_installed.txt"
sort -u "$PRE/packages_installed.txt" -o "$PRE/packages_installed.txt"
rm -f "$PRE/.before_install"

# Detect if running from local directory containing vpsforge.sh
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi

# Change current working directory to safe location (/root or /tmp)
# to avoid 'fatal: Unable to read current working directory' if user runs install while inside /opt/vpsforge/repo
cd /root 2>/dev/null || cd /tmp 2>/dev/null || cd /

if [ -z "${VPSFORGE_REPO_URL:-}" ] && [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/vpsforge.sh" ]; then
  echo "Installing VPSForge from local directory..."
  cp "$SCRIPT_DIR/vpsforge.sh" "$APP_DIR/vpsforge.sh"
  rm -rf "${APP_DIR:?}/lib"
  cp -r "$SCRIPT_DIR/lib" "$APP_DIR/lib"
  if [ -d "$SCRIPT_DIR/.git" ] && [ "$(readlink -f "$SCRIPT_DIR")" != "$(readlink -f "$APP_DIR/repo")" ]; then
    rm -rf "$APP_DIR/repo"
    if git clone "$SCRIPT_DIR" "$APP_DIR/repo" 2>/dev/null; then
      git -C "$APP_DIR/repo" remote set-url origin "$DEFAULT_REPO" 2>/dev/null || true
    else
      rm -rf "$APP_DIR/repo"
      cp -r "$SCRIPT_DIR" "$APP_DIR/repo"
      if [ -d "$APP_DIR/repo/.git" ]; then
        git -C "$APP_DIR/repo" remote set-url origin "$DEFAULT_REPO" 2>/dev/null || true
      fi
    fi
  fi
else
  REPO_URL="${VPSFORGE_REPO_URL:-$DEFAULT_REPO}"
  echo "Cloning and installing VPSForge from $REPO_URL..."
  if [ -d "$APP_DIR/repo/.git" ]; then
    echo "Updating existing repository at $APP_DIR/repo..."
    git -C "$APP_DIR/repo" fetch --all --tags --prune >/dev/null 2>&1 || true
    git -C "$APP_DIR/repo" checkout -f origin/main >/dev/null 2>&1 || git -C "$APP_DIR/repo" checkout -f main >/dev/null 2>&1 || true
  else
    rm -rf "$APP_DIR/repo"
    git clone "$REPO_URL" "$APP_DIR/repo"
  fi
  cp "$APP_DIR/repo/vpsforge.sh" "$APP_DIR/vpsforge.sh"
  rm -rf "${APP_DIR:?}/lib"
  cp -r "$APP_DIR/repo/lib" "$APP_DIR/lib"
fi

if [ -d "$APP_DIR/repo/.git" ]; then
  git -C "$APP_DIR/repo" rev-parse --short HEAD > "$APP_DIR/.installed_commit" 2>/dev/null || true
fi

find "$APP_DIR/lib" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
chmod 755 "$APP_DIR/vpsforge.sh"
find "$APP_DIR/lib" -type f -name "*.sh" -exec chmod 755 {} + 2>/dev/null || true

mkdir -p /usr/local/bin
ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/vpsforge
ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/VPSForge
ln -sf "$APP_DIR/vpsforge.sh" /usr/local/bin/VPSFORGE

cat > /usr/local/bin/vpsforge-update <<'UPD'
#!/bin/bash
# Thin wrapper: all update/rollback logic lives in vpsforge.sh
set -euo pipefail
APP="/opt/vpsforge/vpsforge.sh"
if [ ! -x "$APP" ]; then
  APP="$(command -v vpsforge 2>/dev/null || echo "")"
fi
[ -n "$APP" ] && [ -x "$APP" ] || { echo "ERROR: VPSForge executable not found at $APP."; exit 1; }
exec "$APP" update "$@"
UPD
chmod 755 /usr/local/bin/vpsforge-update

echo "================================================"
echo " VPSForge installed successfully."
echo " Run: vpsforge"
echo "================================================"
