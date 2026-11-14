#!/bin/bash
# Print the SNI (the site name the link shows) of one protocol of a VPS's VPN:
#   reality (default) = the HTTPS site Reality looks like; tls = VLESS+TLS; hy = Hysteria2.
# A VPN made before an SNI could be chosen has none saved: it keeps the default from vpn_globals.
#   vpn_get_sni <vps> [reality|tls|hy]
vpn_get_sni() {
  local vps="${1:?vps}" kind="${2:-reality}" key def sni
  case "$kind" in
    tls) key="user.vpsforge.vpn_tls_sni"; def="$VPN_TLS_SNI";;
    hy)  key="user.vpsforge.vpn_hy_sni";  def="$VPN_HY_SNI";;
    *)   key="user.vpsforge.vpn_sni";     def="$VPN_SNI";;
  esac
  sni=$(incus config get "$vps" "$key" 2>/dev/null || true)
  echo "${sni:-$def}"
}
