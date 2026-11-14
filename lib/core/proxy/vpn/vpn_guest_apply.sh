#!/bin/bash
# Rebuild the Xray and Hysteria2 configs inside a VPS and restart them (after a device is added, removed or renewed).
#   vpn_guest_apply <vps>
vpn_guest_apply() {
  local vps="${1:?vps}"
  incus exec "$vps" --env PORT="$(vpn_inner_port "$vps")" --env SNI="$(vpn_get_sni "$vps")" --env API="$VPN_API_PORT"     --env TLS_PORT="$VPN_TLS_INNER_PORT" --env HY_PORT="$VPN_HY_INNER_PORT" --env HY_MASQ="$VPN_HY_MASQUERADE_URL" \
    -- sh "$VPN_GUEST_DIR/apply.sh" </dev/null
}
