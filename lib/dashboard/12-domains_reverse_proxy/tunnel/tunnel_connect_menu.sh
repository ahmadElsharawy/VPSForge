#!/bin/bash
# Ask which computer runs the site and show only what that computer needs.
#   tunnel_connect_menu <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port> <vps>
tunnel_connect_menu() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:-}" tport="${4:?tunnel port}" lport="${5:?local port}" vps="${6:?vps}" choice
  [ -n "$sshport" ] || sshport=$(get_port "$(get_ip "$vps" 2>/dev/null)" 2>/dev/null || true)
  [ -n "$sshport" ] || sshport=22
  local base="ssh -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:${tport}:localhost:${lport} -p ${sshport} ${user}@${host}"
  while true; do
    echo
    echo "Which computer runs your site (port ${lport})?"
    echo "1) Windows         one line, set up once, runs by itself  (recommended)"
    echo "2) Linux / macOS   keeps the tunnel open and reconnects by itself"
    echo "3) More            try once, new key, remove from a computer"
    echo "0) Done"
    read -r -p "Choice [0=Done]: " choice </dev/tty
    case "$choice" in
      0|"") return 0 ;;
      1) tunnel_connect_show_line "$vps" "$host" "$sshport" "$tport" "$lport" ;;
      2)
        echo
        echo "  Paste this in a terminal (it needs the root login of the VPS):"
        echo "  while true; do ${base}; sleep 5; done"
        ;;
      3) tunnel_connect_more_menu "$user" "$host" "$sshport" "$tport" "$lport" "$vps" ;;
      *) echo "Invalid option." ;;
    esac
  done
}
