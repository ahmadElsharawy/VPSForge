#!/bin/bash
# List every tunnel (grouped by VPS), pick one to manage it, or act on all tunnels of one VPS.
tunnel_my_tunnels_menu() {
  local choice line vps tport
  local -a rows=()
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

    _tunnel_print_table "${rows[@]}"

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
          echo "Invalid option."; sleep 1
        fi
        ;;
    esac
  done
}
