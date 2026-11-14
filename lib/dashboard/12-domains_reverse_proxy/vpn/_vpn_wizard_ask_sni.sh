#!/bin/bash
# Ask for the SNI of one VPN protocol and print it. Enter keeps the last answer (or <default>).
#   _vpn_wizard_ask_sni <pref_key> <default> <protocol_label>
_vpn_wizard_ask_sni() {
  local key="${1:?key}" def="${2:?default}" proto="${3:?protocol}" sni answer
  sni=$(pref_get "$key" "$def")
  read -r -p "SNI for $proto [Enter=$sni]: " answer </dev/tty
  [ -n "$answer" ] && sni="${answer,,}"
  is_valid_vpn_sni "$sni" || { echo "ERROR: '$sni' is not a site name (example: www.microsoft.com)." >&2; return 1; }
  pref_set "$key" "$sni"
  echo "$sni"
}
