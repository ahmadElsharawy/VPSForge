#!/bin/bash
# Remove every iptables rule VPSForge added (port forwards, isolation, NAT, 80/443).
uninstall_remove_firewall() {
  local subnet="" gw="${INCUS_GATEWAY:-}" line proto ext_ip ext_port int_ip int_port
  [ -n "${NETWORK_PREFIX:-}" ] && subnet="${NETWORK_PREFIX}.0/24"
  echo "[2/7] Removing firewall rules..."

  # Saved port forwards (SSH ports and custom rules).
  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
      [ -n "$proto" ] && [ -n "$ext_port" ] || continue
      if [ "${UNINSTALL_DRY_RUN:-0}" = "1" ]; then
        echo "  - remove forward $proto $ext_port -> $int_ip:$int_port"
      else
        port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
      fi
    done < "$PORT_FORWARD_RULES_FILE"
  fi

  # Any leftover DNAT rule pointing into the VPS subnet.
  if [ -n "$subnet" ] && [ "${UNINSTALL_DRY_RUN:-0}" != "1" ]; then
    while read -r line; do
      [ -n "$line" ] || continue
      # shellcheck disable=SC2086
      iptables -t nat -D PREROUTING $line >/dev/null 2>&1 || true
    done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E "DNAT.*--to-destination ${NETWORK_PREFIX}\." | sed 's/^-A PREROUTING //')
  fi

  # Leftover FORWARD rules that mention a VPS address.
  if [ -n "$subnet" ] && [ "${UNINSTALL_DRY_RUN:-0}" != "1" ]; then
    while read -r line; do
      [ -n "$line" ] || continue
      # shellcheck disable=SC2086
      iptables -D FORWARD $line >/dev/null 2>&1 || true
    done < <(iptables -S FORWARD 2>/dev/null | grep -E -- "-[ds] ${NETWORK_PREFIX//./\.}\." | sed 's/^-A FORWARD //')
  fi

  # Isolation / NAT rules from setup_inter_vps_isolation.
  if [ -n "$subnet" ]; then
    uninstall_run iptables -t nat -D POSTROUTING -s "$subnet" ! -d "$subnet" -j MASQUERADE
    uninstall_run iptables -t nat -D POSTROUTING -s "$subnet" -d "$subnet" -j MASQUERADE
    uninstall_run iptables -D FORWARD -s "$subnet" -d "$subnet" -j DROP
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
