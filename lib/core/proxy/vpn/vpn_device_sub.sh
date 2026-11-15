#!/bin/bash
# Print the three links of one device (Reality, Hysteria2, VLESS+TLS), one per line.
#   vpn_device_sub <vps> <device>
vpn_device_sub() {
  local vps="${1:?vps}" name="${2:?name}" ext line id used limit expires keys
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || return 1
  line=$(vpn_list_devices "$vps" | awk -F'|' -v n="$name" '$1 == n { print; exit }')
  IFS='|' read -r _ id _ _ used limit expires _ <<< "$line"
  [ -n "$id" ] || return 1
  keys=$(incus exec "$vps" --env D="$VPN_GUEST_DIR" -- sh -c 'cat "$D/server.pub" "$D/short.id"' </dev/null 2>/dev/null) || return 1
  [ -n "${PUBLIC_IP:-}" ] || get_public_ip >/dev/null 2>&1
  _vpn_links_from "$id" "$(sed -n 1p <<< "$keys")" "$(sed -n 2p <<< "$keys")" \
    "$(_vpn_label_from "$vps" "$used" "$limit" "$expires")" "$ext" \
    "$(vpn_get_sni "$vps")" "$(vpn_get_sni "$vps" tls)" "$(vpn_get_sni "$vps" hy)" "$(vpn_get_hy_port "$vps")"
}
