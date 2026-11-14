#!/bin/bash
# Print the three share links of one device, one per line: VLESS+Reality, Hysteria2, VLESS+TLS.
# All three use the device's own UUID. Import them together or pick the one that works best.
#   vpn_device_sub <vps> <device_name>
vpn_device_sub() {
  local vps="${1:?vps}" name="${2:?name}" ext reality id label
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || return 1
  reality=$(vpn_device_link "$vps" "$name") || return 1
  id=${reality#vless://}
  id=${id%%@*}
  [ -n "$id" ] || return 1
  [ -n "${PUBLIC_IP:-}" ] || get_public_ip >/dev/null 2>&1
  label=$(vpn_device_label "$vps" "$name")
  echo "$reality"
  # Hysteria2 userpass auth needs username:password, where the device name is the user and its UUID the password.
  echo "hysteria2://${name}:${id}@${PUBLIC_IP}:${ext}/?insecure=1&sni=$(vpn_get_sni "$vps" hy)#${label}-HY2"
  echo "vless://${id}@${PUBLIC_IP}:$((ext + VPN_TLS_PORT_OFFSET))?security=tls&encryption=none&alpn=http/1.1&allowInsecure=1&insecure=1&fp=ios&type=tcp&sni=$(vpn_get_sni "$vps" tls)#${label}-TLS"
}
