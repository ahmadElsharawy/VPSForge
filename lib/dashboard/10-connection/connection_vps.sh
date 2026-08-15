#!/bin/bash

bulk_connection_menu() {
  local n ip p
  ask_vps_selection_enter_all || return
  for n in "${SELECTED_VPS[@]}"; do
    ip=$(get_ip "$n"); p=$(get_port "$ip")
    echo
    echo "================================================"
    echo "VPS Name:    $n"
    echo "Public IP:   $PUBLIC_IP"
    echo "Port:        ${p:--}"
    echo "Username:    $(get_vps_user "$n")"
    echo "Password:    $(get_vps_password "$n")"
    [ -n "$p" ] && echo "SSH Command: ssh $(get_vps_user "$n")@$PUBLIC_IP -p $p"
    echo "================================================"
  done
}
