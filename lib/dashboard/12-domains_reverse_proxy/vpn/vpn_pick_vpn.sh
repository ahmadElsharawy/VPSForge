#!/bin/bash
# Choose one VPS that has a VPN. Sets VPN_VPS. Returns 1 on Back or when there is none.
vpn_pick_vpn() {
  local -a rows=()
  local i choice last
  mapfile -t rows < <(vpn_all_vps)
  if [ "${#rows[@]}" -eq 0 ]; then
    echo "No VPN yet. Create one first (option 1)."
    return 1
  fi
  if [ "${#rows[@]}" -eq 1 ]; then
    VPN_VPS="${rows[0]%%|*}"
    return 0
  fi
  last=$(pref_get vpn_vps 1)
  for i in "${!rows[@]}"; do
    echo "  $((i + 1))) ${rows[$i]%%|*}   (port ${rows[$i]#*|} UDP)"
  done
  read -r -p "Which VPN [0=Back, Enter=$last]: " choice </dev/tty
  choice="${choice:-$last}"
  [ "$choice" = "0" ] && return 1
  [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#rows[@]}" ] || { echo "Invalid choice."; return 1; }
  VPN_VPS="${rows[$((choice - 1))]%%|*}"
  pref_set vpn_vps "$choice"
}
