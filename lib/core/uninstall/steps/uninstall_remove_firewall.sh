#!/bin/bash
# Remove every iptables rule VPSForge added (port forwards, isolation, NAT, 80/443).
uninstall_remove_firewall() {
  local subnet="" gw="${INCUS_GATEWAY:-}"
  [ -n "${NETWORK_PREFIX:-}" ] && subnet="${NETWORK_PREFIX}.0/24"
  echo "[2/7] Removing firewall rules..."

  _uninstall_remove_saved_forwards
  _uninstall_remove_subnet_rules "$subnet"

  # Isolation / NAT rules from setup_inter_vps_isolation.
  if [ -n "$subnet" ]; then
    uninstall_run iptables -t nat -D POSTROUTING -s "$subnet" ! -d "$subnet" -j MASQUERADE
    uninstall_run iptables -t nat -D POSTROUTING -s "$subnet" -d "$subnet" -j MASQUERADE
    uninstall_run iptables -D FORWARD -s "$subnet" -d "$subnet" -j DROP
    command -v ip6tables >/dev/null 2>&1 && uninstall_run ip6tables -D FORWARD -i incusbr0 -o incusbr0 -j DROP
    [ -n "$gw" ] && uninstall_run iptables -D FORWARD -i incusbr0 -s "$subnet" -d "$gw" -j ACCEPT
  fi
  uninstall_run iptables -D FORWARD -i incusbr0 -o incusbr0 -j DROP
  uninstall_run iptables -D FORWARD -i incusbr0 ! -o incusbr0 -j ACCEPT
  uninstall_run iptables -D FORWARD -m conntrack --ctstate DNAT -j ACCEPT
  uninstall_run iptables -D FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  # Ports 80/443: remove only if they were not open before VPSForge.
  if [ ! -f "$PRE_INSTALL_DIR/iptables.rules" ] || ! grep -q -- 'dports 80,443' "$PRE_INSTALL_DIR/iptables.rules"; then
    uninstall_run iptables -D INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
  else
    echo "  (ports 80/443 were already open before VPSForge: kept)"
  fi

  [ "${UNINSTALL_DRY_RUN:-0}" = "1" ] || save_iptables
}
