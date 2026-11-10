#!/bin/bash
# Choose one device of the VPN on <vps>. Sets VPN_DEVICE. Returns 1 on Back or when there is none.
#   vpn_pick_device <vps> [prompt]
vpn_pick_device() {
  local vps="${1:?vps}" prompt="${2:-Which device}" i choice
  local -a rows=()
  mapfile -t rows < <(vpn_list_devices "$vps")
  if [ "${#rows[@]}" -eq 0 ]; then
    echo "No devices on the VPN of $vps yet."
    return 1
  fi
  for i in "${!rows[@]}"; do
    IFS='|' read -r n _ _ _ _ lim _ st <<< "${rows[$i]}"
    echo "  $((i + 1))) $n   (limit ${lim:-0} GB, $st)"
  done
  read -r -p "$prompt [0=Back, Enter=1]: " choice </dev/tty
  choice="${choice:-1}"
  [ "$choice" = "0" ] && return 1
  [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#rows[@]}" ] || { echo "Invalid choice."; return 1; }
  VPN_DEVICE="${rows[$((choice - 1))]%%|*}"
}
