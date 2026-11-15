#!/bin/bash
# Print a device's three links (Reality, Hysteria2, VLESS+TLS), one per line, from values already read.
# The only place their format lives: the subscription and "Show the links" both use it.
#   _vpn_links_from <id> <reality_pub> <short_id> <label> <public_port> <reality_sni> <tls_sni> <hy_sni> <hy_udp_port>
_vpn_links_from() {
  local id="$1" pub="$2" sid="$3" label="$4" ext="$5" sni="$6" tls_sni="$7" hy_sni="$8" hy_port="$9"
  echo "vless://${id}@${PUBLIC_IP}:${ext}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${label}-REALITY"
  echo "hysteria2://${id}@${PUBLIC_IP}:${hy_port}/?insecure=1&sni=${hy_sni}#${label}-HY2"
  echo "vless://${id}@${PUBLIC_IP}:$((ext + VPN_TLS_PORT_OFFSET))?security=tls&encryption=none&alpn=http/1.1&allowInsecure=1&insecure=1&fp=ios&type=tcp&sni=${tls_sni}#${label}-TLS"
}
