#!/bin/bash
# Create-VPN wizard step 3 of 4: the site each protocol looks like to anyone watching (SNI):
# Reality first (checked for TLS 1.3 + HTTP/2), then VLESS+TLS and Hysteria2.
vpn_wizard_step_sni() {
  local sni answer
  echo
  echo "Step 3 of 4 - Disguise site (SNI)"
  show_example "www.microsoft.com   (a big HTTPS site that works normally in your country)"
  sni=$(pref_get vpn_sni "$VPN_SNI")
  read -r -p "Site the VPN looks like [Enter=$sni, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  [ -n "$answer" ] && sni="${answer,,}"
  is_valid_vpn_sni "$sni" || { echo "ERROR: '$sni' is not a site name (example: www.microsoft.com)."; return 1; }
  echo "Checking that $sni speaks TLS 1.3 and HTTP/2..."
  vpn_sni_supported "$sni" || { echo "ERROR: $sni does not answer with TLS 1.3 + HTTP/2 from this server. Pick another site."; return 1; }
  VW_SNI="$sni"
  pref_set vpn_sni "$sni"
  # VLESS+TLS and Hysteria2 use a self-signed certificate: any site name works, it is only what a watcher sees
  VW_TLS_SNI=$(_vpn_wizard_ask_sni vpn_tls_sni "$sni" "VLESS+TLS") || return 1
  VW_HY_SNI=$(_vpn_wizard_ask_sni vpn_hy_sni "$sni" "Hysteria2") || return 1
  return 0
}
