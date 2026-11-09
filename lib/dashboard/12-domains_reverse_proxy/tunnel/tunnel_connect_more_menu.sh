#!/bin/bash
# Extra choices for a tunnel: try it once, take the access back with a new key, remove the Windows setup.
#   tunnel_connect_more_menu <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port> <vps>
tunnel_connect_more_menu() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}" vps="${6:?vps}" choice
  echo
  echo "1) Try it once (any system, stops when you close the window)"
  echo "2) New key: every Windows setup made before stops working (take access back)"
  echo "3) Remove the Windows setup from a computer"
  echo "0) Back"
  read -r -p "Choice [0=Back]: " choice </dev/tty
  case "$choice" in
    1)
      echo
      echo "  Paste this in a terminal or PowerShell (it needs the root login of the VPS):"
      echo "  ssh -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:${tport}:localhost:${lport} -p ${sshport} ${user}@${host}"
      ;;
    2) tunnel_connect_show_line "$vps" "$host" "$sshport" "$tport" "$lport" renew ;;
    3)
      echo
      echo "  Paste this line in PowerShell on that computer:"
      print_windows_tunnel_remove "$(tunnel_access_user "$tport")" "$host" "$sshport" "$tport" "$lport"
      ;;
  esac
}
