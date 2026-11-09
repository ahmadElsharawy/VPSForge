#!/bin/bash
# List every tunnel (grouped by VPS), pick one to manage it, or act on all tunnels of one VPS.
tunnel_my_tunnels_menu() {
  local choice line vps tport lport ext domain state idx addr conn
  local -a rows=()
  local -A live=()
  while true; do
    mapfile -t rows < <(tunnel_all_records 2>/dev/null | sort -t'|' -k1,1 -k2,2n)
    clear
    echo "================================================================"
    echo "                      MY TUNNELS"
    echo "================================================================"
    if [ "${#rows[@]}" -eq 0 ]; then
      echo "No tunnels yet. Add one from the previous menu."
      pause
      return
    fi

    # "connected" = your computer is linked and the tunnel port listens inside the VPS (one check per VPS).
    live=()
    for line in "${rows[@]}"; do
      IFS='|' read -r vps _ <<< "$line"
      [ -n "${live[$vps]+x}" ] && continue
      live[$vps]=" $(list_vps_listening_ports "$vps" 2>/dev/null | tr '\n' ' ') "
    done

    printf '%-4s %-12s %-38s %-9s %-8s %s\n' "#" VPS "PUBLIC ADDRESS" "VPS PORT" "MY PC" "STATE"
    echo "----------------------------------------------------------------------------------------"
    idx=0
    for line in "${rows[@]}"; do
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
    echo "Type a number to manage that tunnel, B = all tunnels of one VPS, 0 = Back"
    read -r -p "Choice [0=Back]: " choice
    case "${choice,,}" in
      0|"") return ;;
      b) tunnel_bulk_menu ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#rows[@]}" ]; then
          IFS='|' read -r vps tport _ <<< "${rows[$((choice - 1))]}"
          tunnel_actions_menu "$vps" "$tport"
        else
          echo "Invalid choice."; sleep 1
        fi
        ;;
    esac
  done
}
