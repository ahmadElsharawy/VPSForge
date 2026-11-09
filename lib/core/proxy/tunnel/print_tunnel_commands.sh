#!/bin/bash
# Show the exact command to run on YOUR computer to open the tunnel (once, or forever with auto-reconnect).
#   print_tunnel_commands <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port>
print_tunnel_commands() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}"
  local base="ssh -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:${tport}:localhost:${lport} -p ${sshport} ${user}@${host}"
  echo "Run this on YOUR computer (Windows PowerShell, Linux or macOS) while your site runs on port ${lport}:"
  echo
  echo "   ${base}"
  echo
  echo "To keep it open and reconnect by itself:"
  echo "   Windows PowerShell:  while (\$true) { ${base}; Start-Sleep 5 }"
  echo "   Linux / macOS:       while true; do ${base}; sleep 5; done"
}
