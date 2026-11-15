#!/bin/bash
# Stop and remove every VPN subscription web server (vpsforge-vpnsub-<port>) and close its firewall
# opening. Their VPSs are already gone at this point, so vpn_remove cannot be used.
_uninstall_remove_vpn_sub_servers() {
  local file unit ext found=0
  for file in /etc/systemd/system/vpsforge-vpnsub-*.service; do
    [ -f "$file" ] || continue
    found=1
    unit=$(basename "$file" .service); ext="${unit#vpsforge-vpnsub-}"
    uninstall_run systemctl disable --now "$unit"
    uninstall_run rm -f "$file"
    [[ "$ext" =~ ^[0-9]+$ ]] && uninstall_run iptables -D INPUT -p tcp --dport "$((ext + 1))" -j ACCEPT
  done
  [ "$found" -eq 1 ] && uninstall_run systemctl daemon-reload
  return 0
}
