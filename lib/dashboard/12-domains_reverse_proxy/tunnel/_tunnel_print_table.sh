#!/bin/bash
# Print formatted table of tunnels with live connection state.
#   _tunnel_print_table <row1> [row2 ...]
_tunnel_print_table() {
  local line vps tport lport ext domain state idx addr conn
  local -A live=()

  # "connected" = your computer is linked and the tunnel port listens inside the VPS (one check per VPS).
  for line in "$@"; do
    IFS='|' read -r vps _ <<< "$line"
    [ -n "${live[$vps]+x}" ] && continue
    live[$vps]=" $(list_vps_listening_ports "$vps" 2>/dev/null | tr '\n' ' ') "
  done

  printf '%-4s %-12s %-38s %-9s %-8s %s\n' "#" VPS "PUBLIC ADDRESS" "VPS PORT" "MY PC" "STATE"
  echo "----------------------------------------------------------------------------------------"
  idx=0
  for line in "$@"; do
    IFS='|' read -r vps tport lport ext domain state <<< "$line"
    idx=$((idx + 1))
    if [ -n "$domain" ]; then addr="https://$domain"; else addr="http://${PUBLIC_IP:-IP}:$ext"; fi
    conn=""
    if [ "$state" = "active" ]; then
      if [[ "${live[$vps]}" == *" $tport "* ]]; then conn="ACTIVE - connected"; else conn="ACTIVE - waiting for your PC"; fi
    else
      conn="STOPPED"
    fi
    printf '%-4s %-12s %-38s %-9s %-8s %s\n' "$idx" "$vps" "$addr" "$tport" "$lport" "$conn"
  done
  echo "----------------------------------------------------------------------------------------"
}
