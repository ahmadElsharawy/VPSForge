#!/bin/bash

SETTINGS_FILE="/opt/vpsforge/settings.conf"
AUTO_REFRESH="on"
REFRESH_INTERVAL=10
AUTO_START_ON_LOGIN="off"

load_settings() {
  if [ -f "$SETTINGS_FILE" ]; then
    # shellcheck disable=SC1090
    source "$SETTINGS_FILE"
  fi
  [[ "$AUTO_REFRESH" = "on" || "$AUTO_REFRESH" = "off" ]] || AUTO_REFRESH="on"
  [[ "$REFRESH_INTERVAL" =~ ^[1-9][0-9]*$ ]] || REFRESH_INTERVAL=10
  [[ "${AUTO_START_ON_LOGIN:-off}" = "on" || "${AUTO_START_ON_LOGIN:-off}" = "off" ]] || AUTO_START_ON_LOGIN="off"
  apply_autostart_login_config
}

save_settings() {
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  {
    printf 'AUTO_REFRESH=%q\n' "$AUTO_REFRESH"
    printf 'REFRESH_INTERVAL=%q\n' "$REFRESH_INTERVAL"
    printf 'AUTO_START_ON_LOGIN=%q\n' "$AUTO_START_ON_LOGIN"
  } > "$SETTINGS_FILE"
  apply_autostart_login_config
}

apply_autostart_login_config() {
  local autostart_file="/etc/profile.d/vpsforge-autostart.sh"
  if [ "${AUTO_START_ON_LOGIN:-off}" = "on" ]; then
    if [ -d /etc/profile.d ] && { [ -w /etc/profile.d 2>/dev/null ] || [ "${EUID:-$(id -u)}" -eq 0 ]; }; then
      cat > "$autostart_file" <<'EOF_AUTOSTART'
# VPSForge Auto-Start on Interactive SSH / Terminal Login
if [ -t 0 ] && [ -n "${TERM:-}" ] && [ -z "${VPSFORGE_SESSION_ACTIVE:-}" ]; then
  # Only trigger in top-level interactive login shells
  if [ -x /usr/local/bin/vpsforge ] && [ -f /opt/vpsforge/settings.conf ]; then
    if grep -Eq '^[[:space:]]*AUTO_START_ON_LOGIN=["'\''"]?on["'\''"]?' /opt/vpsforge/settings.conf 2>/dev/null; then
      export VPSFORGE_SESSION_ACTIVE=1
      if [ "${EUID:-$(id -u)}" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
        sudo -E /usr/local/bin/vpsforge
      else
        /usr/local/bin/vpsforge
      fi
      unset VPSFORGE_SESSION_ACTIVE
    fi
  fi
fi
EOF_AUTOSTART
      chmod 644 "$autostart_file" 2>/dev/null || true
    fi
  else
    if [ -f "$autostart_file" ]; then
      rm -f "$autostart_file" 2>/dev/null || true
    fi
  fi
}

extract_version_from_text() {
  tr -d '\r' | grep -oE 'v[0-9]+(\.[0-9]+)*' | head -n1 || true
}

verify_installed_version() {
  local app="$1" target="$2" installed="" attempt

  for attempt in $(seq 1 10); do
    installed=$("$app" --version 2>/dev/null | extract_version_from_text)
    [ "$installed" = "$target" ] && return 0
    sleep 1
  done

  installed=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$app" 2>/dev/null | head -n1)
  [ "$installed" = "$target" ]
}
