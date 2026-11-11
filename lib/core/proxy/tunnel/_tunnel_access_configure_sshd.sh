#!/bin/bash
# Configure and validate the restricted sshd Match rules inside a VPS for one tunnel port.
# If sshd rejects the configuration, cleans up the drop-in conf and user account.
#   _tunnel_access_configure_sshd <vps> <user> <tunnel_port>
_tunnel_access_configure_sshd() {
  local vps="${1:?vps}" user="${2:?user}" tport="${3:?tunnel port}"
  incus exec "$vps" --env TUSER="$user" --env TPORT="$tport" -- sh -c '
    grep -qs "sshd_config.d" /etc/ssh/sshd_config || echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    conf="/etc/ssh/sshd_config.d/98-vpsforge-tunnel-$TPORT.conf"
    printf "Match User %s\n  PasswordAuthentication yes\n  AllowTcpForwarding remote\n  AllowStreamLocalForwarding no\n  PermitTunnel no\n  PermitListen 0.0.0.0:%s\n  PermitOpen none\n  PermitTTY no\n  X11Forwarding no\n  AllowAgentForwarding no\n  ForceCommand cat /etc/vpsforge-tunnel/%s.ps1\n" "$TUSER" "$TPORT" "$TPORT" > "$conf"
    if sshd -t && { systemctl try-reload-or-restart ssh || systemctl try-reload-or-restart sshd || service ssh reload; }; then exit 0; fi
    rm -f "$conf"; pkill -KILL -u "$TUSER" >/dev/null 2>&1; userdel -r "$TUSER" >/dev/null 2>&1; rm -f "/etc/vpsforge-tunnel/$TPORT".*
    exit 1
  ' </dev/null >/dev/null 2>&1
}
