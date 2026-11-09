#!/bin/bash
# Start, stop or delete ALL tunnels of one VPS at once.
tunnel_bulk_menu() {
  local vps choice answer line tport
  local -a tports=()
  echo
  read -r -p "VPS name [0=Back]: " vps </dev/tty
  { [ -z "$vps" ] || [ "$vps" = "0" ]; } && return
  mapfile -t tports < <(tunnel_get_records "$vps" | cut -d'|' -f1)
  if [ "${#tports[@]}" -eq 0 ]; then
    echo "'$vps' has no tunnels."; pause; return
  fi

  echo "$vps has ${#tports[@]} tunnel(s)."
  echo "1) Start all"
  echo "2) Stop all"
  echo "3) Delete all"
  echo "0) Back"
  read -r -p "Choice [0=Back]: " choice </dev/tty
  case "$choice" in
    1) for tport in "${tports[@]}"; do tunnel_start "$vps" "$tport" && echo "Started $tport"; done ;;
    2) for tport in "${tports[@]}"; do tunnel_stop "$vps" "$tport" && echo "Stopped $tport"; done ;;
    3)
      read -r -p "Delete ALL ${#tports[@]} tunnels of $vps? [y/N]: " answer </dev/tty
      if [[ "${answer,,}" =~ ^y ]]; then
        for tport in "${tports[@]}"; do tunnel_delete "$vps" "$tport"; done
        echo "Deleted."
      fi
      ;;
    *) return ;;
  esac
  pause
}
