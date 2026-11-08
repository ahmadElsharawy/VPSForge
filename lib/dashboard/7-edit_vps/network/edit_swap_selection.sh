#!/bin/bash
# Swap IP and SSH port: with 2 VPSs selected swap them; with 1 ask for the other VPS.
edit_swap_selection() {
  case "${#SELECTED_VPS[@]}" in
    1) edit_swap_ip "${SELECTED_VPS[0]}";;
    2) swap_vps_ips_and_ports "${SELECTED_VPS[0]}" "${SELECTED_VPS[1]}";;
    *) echo "Select exactly 1 VPS (then pick the other one) or exactly 2 VPSs to swap.";;
  esac
}
