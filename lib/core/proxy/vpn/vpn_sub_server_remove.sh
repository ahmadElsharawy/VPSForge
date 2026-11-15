#!/bin/bash
# Stop and remove the permanent web server of one VPN (by its public port), close its firewall
# opening and delete its tokens, subscription files and pages: every link of that VPN stops.
#   vpn_sub_server_remove <vpn_public_port>
vpn_sub_server_remove() {
  local ext="${1:?port}" port unit
  [[ "$ext" =~ ^[0-9]+$ ]] || return 1
  port=$((ext + 1)); unit="vpsforge-vpnsub-$ext"
  if [ -f "/etc/systemd/system/$unit.service" ]; then
    systemctl disable --now "$unit" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/$unit.service"
    systemctl daemon-reload
  fi
  while iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; do :; done
  save_iptables
  rm -rf "${VPN_SUB_DIR:?}/$ext"
  return 0
}
