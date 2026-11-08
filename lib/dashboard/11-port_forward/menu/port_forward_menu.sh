#!/bin/bash

port_forward_menu() {
  local c confirm
  while :; do
    clear
    echo "================================================"
    echo "                  PORT FORWARD"
    echo "================================================"
    echo
    port_forward_list_rules
    echo
    echo "0) Back"
    echo "1) Add Rule"
    echo "2) Edit Rule"
    echo "3) Delete Rule"
    echo "4) Delete ALL Rules"
    echo "5) Active NAT Status"
    echo
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"

    case "$c" in
      1) _pf_interactive_add && pause;;
      2) _pf_interactive_edit && pause;;
      3) _pf_interactive_delete && pause;;
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
