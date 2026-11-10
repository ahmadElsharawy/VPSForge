#!/bin/bash
# Rebuild Xray's config inside a VPS and restart it (after a device is added, removed or renewed).
#   vpn_guest_apply <vps>
vpn_guest_apply() {
  local vps="${1:?vps}"
  incus exec "$vps" --env PORT="$(vpn_inner_port "$vps")" --env SNI="$VPN_SNI" --env API="$VPN_API_PORT" \
    -- sh "$VPN_GUEST_DIR/apply.sh" </dev/null
}
