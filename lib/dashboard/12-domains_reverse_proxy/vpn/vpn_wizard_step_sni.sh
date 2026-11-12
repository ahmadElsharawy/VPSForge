#!/bin/bash
# Create-VPN wizard step 3 of 4: the HTTPS site the VPN looks like to anyone watching (Reality SNI).
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
  return 0
}
