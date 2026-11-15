#!/bin/bash
# Run the limits checker inside one VPS: adds up usage and, unless "collect" is given,
# switches off devices that passed their data limit or their days.
#   vpn_guest_check <vps> [collect]
vpn_guest_check() {
  local vps="${1:?vps}"
  # the same settings as vpn_guest_apply: check.sh runs apply.sh when it switches a device off
  incus exec "$vps" --env PORT="$(vpn_inner_port "$vps")" --env SNI="$(vpn_get_sni "$vps")" --env API="$VPN_API_PORT" \
    --env TLS_PORT="$VPN_TLS_INNER_PORT" --env HY_PORT="$VPN_HY_INNER_PORT" --env HY_MASQ="$VPN_HY_MASQUERADE_URL" \
    -- sh "$VPN_GUEST_DIR/check.sh" ${2:+"$2"} </dev/null
}
