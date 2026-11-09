#!/bin/bash
# Ask which computer runs the site and show ONLY the matching instructions, clearly framed.
#   tunnel_connect_menu <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port>
tunnel_connect_menu() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}" choice
  local base="ssh -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:${tport}:localhost:${lport} -p ${sshport} ${user}@${host}"
  while true; do
    echo
    echo "Which computer runs your site (port ${lport})?"
    echo "1) Windows         set up ONCE: runs by itself, hidden, with a desktop on/off icon  (recommended)"
    echo "2) Windows         remove that setup"
    echo "3) Linux / macOS   keeps the tunnel open and reconnects by itself"
    echo "4) Any system      just try it once (stops when you close the window)"
    echo "0) Done"
    read -r -p "Choice [0=Done]: " choice </dev/tty
    case "$choice" in
      0|"") return 0 ;;
      1)
        echo
        echo "  1. Open PowerShell (Start menu, type: PowerShell)"
        echo "  2. Copy EVERYTHING between the two lines below and paste it (right-click)"
        echo "  3. When asked, type the VPS password one time (user '${user}', main menu 8 shows it)"
        echo "  ---------------------------- COPY FROM HERE ----------------------------"
        print_windows_tunnel_setup "$user" "$host" "$sshport" "$tport" "$lport"
        echo "  ----------------------------- UNTIL HERE -------------------------------"
        echo "  After that you do nothing: it starts by itself at every Windows login."
        ;;
      2)
        echo
        echo "  Paste this line in PowerShell:"
        print_windows_tunnel_remove "$user" "$host" "$sshport" "$tport" "$lport"
        ;;
      3)
        echo
        echo "  Paste this in a terminal:"
        echo "  while true; do ${base}; sleep 5; done"
        ;;
      4)
        echo
        echo "  Paste this in a terminal or PowerShell:"
        echo "  ${base}"
        ;;
      *) echo "Invalid option." ;;
    esac
  done
}
