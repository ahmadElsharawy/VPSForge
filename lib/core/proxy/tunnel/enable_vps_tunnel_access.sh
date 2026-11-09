#!/bin/bash
# Let a VPS accept reverse tunnels (ssh -R) from your own computer: the tunnel port must listen on
# every address of the VPS so the server can reach it. Only a small ssh drop-in file is added.
# On failure the reason is printed.
#   enable_vps_tunnel_access <vps>
enable_vps_tunnel_access() {
  local vps="${1:?vps}" out cfg
  out=$(incus exec "$vps" -- sh -c '
    mkdir -p /etc/ssh/sshd_config.d
    grep -qs "sshd_config.d" /etc/ssh/sshd_config || echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    printf "GatewayPorts yes\nAllowTcpForwarding yes\nClientAliveInterval 30\nClientAliveCountMax 3\n" > /etc/ssh/sshd_config.d/99-vpsforge-tunnel.conf
    sshd -t || { rm -f /etc/ssh/sshd_config.d/99-vpsforge-tunnel.conf; exit 1; }
    systemctl try-reload-or-restart ssh || systemctl try-reload-or-restart sshd || service ssh reload || rc-service sshd reload || exit 1
  ' </dev/null 2>&1) || { echo "$out" | tail -n 2; return 1; }
  # (read the whole output first: grep -q ending early would break the pipe under pipefail)
  cfg=$(incus exec "$vps" -- sshd -T </dev/null 2>/dev/null)
  grep -qi '^gatewayports yes' <<< "$cfg"
}
