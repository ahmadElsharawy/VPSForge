#!/bin/bash
# Display SSH connection details (IP, port, user, password) for selected VPSs.
bulk_connection_menu() {
  local vps_name vps_ip ssh_port
  ask_vps_selection_enter_all || return
  for vps_name in "${SELECTED_VPS[@]}"; do
    vps_ip=$(get_ip "$vps_name")
    ssh_port=$(get_port "$vps_ip")
    echo
    echo "================================================"
    echo "VPS Name:    $vps_name"
    echo "Public IP:   $PUBLIC_IP"
    echo "Port:        ${ssh_port:--}"
    echo "Username:    $(get_vps_user "$vps_name")"
    echo "Password:    $(get_vps_password "$vps_name")"
    [ -n "$ssh_port" ] && echo "SSH Command: ssh $(get_vps_user "$vps_name")@$PUBLIC_IP -p $ssh_port"
    echo "================================================"
  done
}
