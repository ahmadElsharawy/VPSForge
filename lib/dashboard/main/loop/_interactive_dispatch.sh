#!/bin/bash
# Dispatches a chosen numeric action from the interactive dashboard menu.
_interactive_dispatch() {
  local choice="$1"
  case "$choice" in
    0)
      get_network_info
      get_public_ip
      return 2
      ;;
    1)  add_menu;;
    2)  delete_vps_menu;;
    3)  start_vps_menu;;
    4)  stop_vps_menu;;
    5)  restart_vps_menu;;
    6)  reinstall_vps_menu;;
    7)  edit_vps_menu;;
    8)  bulk_details_menu; pause;;
    9)  shell_menu;;
    10) bulk_connection_menu; pause;;
    11) port_forward_menu;;
    12) proxy_menu;;
    13) backup_vps_menu;;
    14) settings_menu;;
    15) return 15;;
    *)  return 2;;
  esac
  return 0
}
