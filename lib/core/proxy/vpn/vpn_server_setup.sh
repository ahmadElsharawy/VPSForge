#!/bin/bash
# Prepare the VPN inside a VPS: Reality keys, the two self-signed certificates, the apply/check scripts, then start the services.
#   vpn_server_setup <vps>
vpn_server_setup() {
  local vps="${1:?vps}"
  vpn_guest_check_script | incus exec "$vps" --env D="$VPN_GUEST_DIR" -- sh -c 'umask 077; mkdir -p "$D"; cat > "$D/check.sh"' \
    || { echo "ERROR: could not write the VPN limits checker inside $vps."; return 1; }
  vpn_guest_apply_script | incus exec "$vps" --env D="$VPN_GUEST_DIR" --env TLS_SNI="$(vpn_get_sni "$vps" tls)" --env HY_SNI="$(vpn_get_sni "$vps" hy)" -- sh -c '
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
    if [ ! -s "$D/tls.key" ] || [ ! -s "$D/tls.crt" ]; then
      openssl ecparam -genkey -name prime256v1 -out "$D/tls.key"
      openssl req -new -x509 -days 3650 -key "$D/tls.key" -out "$D/tls.crt" -subj "/CN=$TLS_SNI"
    fi
    if [ ! -s "$D/hy.key" ] || [ ! -s "$D/hy.crt" ]; then
      openssl ecparam -genkey -name prime256v1 -out "$D/hy.key"
      openssl req -new -x509 -days 3650 -key "$D/hy.key" -out "$D/hy.crt" -subj "/CN=$HY_SNI"
    fi
    [ -s "$D/server.key" ] && [ -s "$D/server.pub" ] && [ -s "$D/short.id" ]
    [ -s "$D/tls.key" ] && [ -s "$D/tls.crt" ] && [ -s "$D/hy.key" ] && [ -s "$D/hy.crt" ]
    touch "$D/devices.txt"
  ' || { echo "ERROR: could not prepare the VPN keys and certificates inside $vps."; return 1; }
  vpn_guest_apply "$vps" || { echo "ERROR: the VPN did not start inside $vps."; return 1; }
}
