#!/bin/bash
# VPSForge v1.0.0 — Edit: Swap IP & Port for selection.

# Initiates an IP and port swap for selected VPS instances.
edit_swap_selection() {
  case "${#SELECTED_VPS[@]}" in
    1) edit_swap_ip "${SELECTED_VPS[0]}";;
    2) swap_vps_ips_and_ports "${SELECTED_VPS[0]}" "${SELECTED_VPS[1]}";;
    *) echo "Select exactly 1 VPS (then pick the other one) or exactly 2 VPSs to swap.";;
  esac
}
