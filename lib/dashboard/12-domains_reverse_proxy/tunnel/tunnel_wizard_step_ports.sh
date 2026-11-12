#!/bin/bash
# Wizard step 2 of 4: the port that opens inside the VPS, and the port your site uses on your computer.
tunnel_wizard_step_ports() {
  local tport lport sshport answer
  echo
  echo "Step 2 of 4 - Ports"
  show_example "8080 inside the VPS  <-  3000 on your computer (where your site runs)"
  tport=$(pref_get tunnel_port 8080)
  lport=$(pref_get tunnel_local_port 3000)
  # Editing a tunnel: Enter keeps THIS tunnel's ports, not the last ones typed anywhere.
  if [ -n "${TW_EDIT_TPORT:-}" ]; then
    tport="${TW_TPORT:-$tport}"; lport="${TW_LPORT:-$lport}"
  fi

  read -r -p "Port to open on the VPS [Enter=$tport, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  [ -n "$answer" ] && tport="$answer"
  if ! [[ "$tport" =~ ^[0-9]+$ ]] || [ "$tport" -lt 1024 ] || [ "$tport" -gt 65535 ]; then
    echo "ERROR: choose a port between 1024 and 65535."; return 1
  fi
  sshport=$(get_vps_saved_port "$TW_VPS")
  [ "$tport" = "$sshport" ] && { echo "ERROR: that is the SSH port of $TW_VPS."; return 1; }
  if [ "$tport" != "$TW_EDIT_TPORT" ] && tunnel_get_records "$TW_VPS" | awk -F'|' -v p="$tport" '$1 == p { f = 1 } END { exit !f }'; then
    echo "ERROR: $TW_VPS already has a tunnel on port $tport."; return 1
  fi

  local busy
  busy=$(list_vps_listening_ports "$TW_VPS" 2>/dev/null || true)
  if [ "$tport" != "$TW_EDIT_TPORT" ] && grep -qx "$tport" <<< "$busy"; then
    echo "ERROR: port $tport is already used by a service inside $TW_VPS. Choose another."; return 1
  fi

  read -r -p "Port of your site on your computer [Enter=$lport, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  [ -n "$answer" ] && lport="$answer"
  if ! [[ "$lport" =~ ^[0-9]+$ ]] || [ "$lport" -lt 1 ] || [ "$lport" -gt 65535 ]; then
    echo "ERROR: choose a port between 1 and 65535."; return 1
  fi

  TW_TPORT="$tport"; TW_LPORT="$lport"
  pref_set tunnel_port "$tport"; pref_set tunnel_local_port "$lport"
  return 0
}
