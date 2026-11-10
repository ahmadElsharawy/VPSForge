#!/bin/bash
# Prepare Xray inside a VPS: Reality keys, the apply/check scripts, then start the service.
#   vpn_server_setup <vps>
vpn_server_setup() {
  local vps="${1:?vps}"
  vpn_guest_check_script | incus exec "$vps" --env D="$VPN_GUEST_DIR" -- sh -c 'umask 077; mkdir -p "$D"; cat > "$D/check.sh"' \
    || { echo "ERROR: could not write the VPN limits checker inside $vps."; return 1; }
  vpn_guest_apply_script | incus exec "$vps" --env D="$VPN_GUEST_DIR" -- sh -c '
    set -e
    umask 077
    mkdir -p "$D"
    cat > "$D/apply.sh"
    if [ ! -s "$D/server.key" ]; then
      k=$(/usr/local/bin/xray x25519)
      printf "%s\n" "$k" | awk -F": *" "/Private/ { print \$2; exit }" > "$D/server.key"
      printf "%s\n" "$k" | awk -F": *" "/Public|Password/ { print \$2; exit }" > "$D/server.pub"
      head -c 8 /dev/urandom | od -An -tx1 | tr -d " \n" > "$D/short.id"
    fi
    [ -s "$D/server.key" ] && [ -s "$D/server.pub" ] && [ -s "$D/short.id" ]
    touch "$D/devices.txt"
  ' || { echo "ERROR: could not prepare the Xray keys inside $vps."; return 1; }
  vpn_guest_apply "$vps" || { echo "ERROR: Xray did not start inside $vps."; return 1; }
}
