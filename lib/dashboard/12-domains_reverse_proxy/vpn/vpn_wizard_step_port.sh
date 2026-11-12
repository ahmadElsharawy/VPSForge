#!/bin/bash
# Create-VPN wizard step 2 of 4: the public port of the VPN on this server (TCP).
vpn_wizard_step_port() {
  local port answer
  echo
  echo "Step 2 of 4 - Public port"
  show_example "8443  (open TCP 8443 and 8444 in your cloud firewall: the VPN and its QR page)"
  port=$(pref_get vpn_port 8443)
  read -r -p "VPN port on this server [Enter=$port, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  [ -n "$answer" ] && port="$answer"
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65534 ]; then
    echo "ERROR: choose a port between 1024 and 65535."; return 1
  fi
  local qr_port=$((port + 1))
  if awk -F'|' -v p="$port" '$3 == p { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
    echo "ERROR: port $port is already used by another forward (menu 11)."; return 1
  fi
  if awk -F'|' -v p="$qr_port" '$3 == p { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
    echo "ERROR: QR page port $qr_port is already used by another forward (menu 11)."; return 1
  fi
  port_forward_host_conflict "$port" tcp >/dev/null 2>&1 || { port_forward_host_conflict "$port" tcp; return 1; }
  port_forward_host_conflict "$qr_port" tcp >/dev/null 2>&1 || { port_forward_host_conflict "$qr_port" tcp; return 1; }
  VW_PORT="$port"
  pref_set vpn_port "$port"
  return 0
}
