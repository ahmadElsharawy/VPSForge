#!/bin/bash
# Print the permanent subscription link of a device: http://SERVER:<VPN port + 1>/s/<token>
#   vpn_sub_url <vps> <device>
vpn_sub_url() {
  local vps="${1:?vps}" name="${2:?device}" ext tok
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || return 1
  tok=$(vpn_sub_token "$vps" "$name") || return 1
  [ -n "${PUBLIC_IP:-}" ] || get_public_ip >/dev/null 2>&1
  # https when the subscription server has a TLS cert (the normal case), http only as a fallback.
  local scheme="http"
  [ -f "$VPN_SUB_DIR/.tls/cert.pem" ] && scheme="https"
  echo "${scheme}://${PUBLIC_IP}:$((ext + 1))/s/${tok}"
}
