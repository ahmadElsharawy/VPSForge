#!/bin/bash
# Configures or removes the /etc/profile.d autostart script for interactive SSH login.
apply_autostart_login_config() {
  local autostart_file="/etc/profile.d/vpsforge-autostart.sh"
  if [ "${AUTO_START_ON_LOGIN:-off}" = "on" ]; then
    if [ -d /etc/profile.d ] && { [ -w /etc/profile.d ] || [ "${EUID:-$(id -u)}" -eq 0 ]; }; then
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
