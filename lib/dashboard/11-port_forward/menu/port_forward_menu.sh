#!/bin/bash
# Interactive menu for managing port forward rules (add, edit, delete, status).
port_forward_menu() {
  local choice confirm
  while :; do
    clear
    echo "================================================"
    echo "                  PORT FORWARD"
    echo "================================================"
    echo
    port_forward_list_rules
    echo
    echo "0) Back"
    echo "1) Add Rule          e.g. server port 8080 -> VPS web1 port 80"
    echo "2) Edit Rule          change the VPS or ports of a rule"
    echo "3) Delete Rule        e.g. 2   or   1,3   or   1-3"
    echo "4) Delete ALL Rules   closes every forwarded port (SSH ports come back with Settings > Repair)"
    echo "5) Active NAT Status   what is really open on the server right now"
    echo
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"

    case "$choice" in
      1) _pf_interactive_add; pause;;
      2) _pf_interactive_edit; pause;;
      3) _pf_interactive_delete; pause;;
      4)
        read -r -p "Are you sure you want to delete ALL port-forward rules? (y/N): " confirm
        if [[ "${confirm,,}" =~ ^y ]]; then
          port_forward_cli delete-all
          pause
        fi
        ;;
      5) port_forward_cli status; pause;;
      0) return;;
      *) sleep 1;;
    esac
  done
}
