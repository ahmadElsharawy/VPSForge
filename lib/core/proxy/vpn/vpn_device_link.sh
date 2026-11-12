#!/bin/bash
# Print the VLESS link of one device (what you scan or paste into v2rayNG / Streisand / v2Box).
# The name after # is <public_ip>-<vps>-<days>-<GB>, so the app shows it by itself.
#   vpn_device_link <vps> <device_name>
vpn_device_link() {
  local vps="${1:?vps}" name="${2:?name}" ext info id pub sid label
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || return 1
  info=$(incus exec "$vps" --env D="$VPN_GUEST_DIR" --env NAME="$name" -- sh -c '
    cd "$D" || exit 1
    id=$(awk -F"|" -v n="$NAME" "\$1 == n { print \$2; exit }" devices.txt)
    [ -n "$id" ] || exit 1
    echo "$id $(cat server.pub) $(cat short.id)"
  ' </dev/null 2>/dev/null) || return 1
  read -r id pub sid <<< "$info"
  [ -n "$id" ] && [ -n "$pub" ] || return 1
  [ -n "${PUBLIC_IP:-}" ] || get_public_ip >/dev/null 2>&1
  label=$(vpn_device_label "$vps" "$name")
  echo "vless://${id}@${PUBLIC_IP}:${ext}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$(vpn_get_sni "$vps")&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${label}"
}
