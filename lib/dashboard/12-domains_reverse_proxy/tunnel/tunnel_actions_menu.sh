#!/bin/bash
# Actions on ONE tunnel: start, stop, edit, delete, show the connect command.
#   tunnel_actions_menu <vps> <tunnel_port>
tunnel_actions_menu() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" choice rec lport ext domain state answer
  while true; do
    rec=$(tunnel_get_records "$vps" | awk -F'|' -v p="$tport" '$1 == p { print; exit }')
    [ -n "$rec" ] || return 0
    IFS='|' read -r _ lport ext domain state <<< "$rec"
    clear
    local addr
    if [ -n "$domain" ]; then addr="https://$domain"; else addr="http://${PUBLIC_IP:-IP}:$ext"; fi
    echo "================================================================"
    echo "   TUNNEL: $addr  ->  $vps:$tport  ->  my PC:$lport"
    echo "   State: ${state^^}"
    echo "================================================================"
    echo "1) Start        open it to the internet"
    echo "2) Stop         close it (kept in the list, start it again any time)"
    echo "3) Edit         change the ports or the public address"
    echo "4) Delete       remove it completely"
    echo "5) Show the command to run on my computer"
    echo "0) Back"
    read -r -p "Choice [0=Back]: " choice </dev/tty
    case "$choice" in
      0|"") return ;;
      1) tunnel_start "$vps" "$tport" && echo "Started." ; pause ;;
      2) tunnel_stop "$vps" "$tport" && echo "Stopped." ; pause ;;
      3) tunnel_edit "$vps" "$tport"; tport="${TW_TPORT:-$tport}"; pause ;;
      4)
        read -r -p "Delete this tunnel for good? [y/N]: " answer </dev/tty
        if [[ "${answer,,}" =~ ^y ]]; then tunnel_delete "$vps" "$tport"; echo "Deleted."; pause; return; fi
        ;;
      5) tunnel_show_connect "$vps" "$tport"; pause ;;
      *) echo "Invalid option."; sleep 1 ;;
    esac
  done
}
