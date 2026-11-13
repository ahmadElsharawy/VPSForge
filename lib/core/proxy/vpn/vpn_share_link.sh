#!/bin/bash
# Make a short-lived page for one device: http://SERVER:<port>/<secret>/ shows the QR code of its
# VLESS link and a "Copy link" button. The page uses the VPN's port number + 1 (TCP), works for
# <minutes>, then the small server stops, its firewall opening is closed and its copy is deleted.
# Sets VPN_SHARE_URL and prints it.
#   vpn_share_link <vps> <device_name> [minutes]
vpn_share_link() {
  local vps="${1:?vps}" name="${2:?name}" minutes="${3:-10}" ext port secret tmp png helper label link
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || { echo "ERROR: $vps has no VPN."; return 1; }
  port=$((ext + 1))
  helper="${LIB_DIR:-/opt/vpsforge/lib}/core/proxy/vpn/vpn_once_server.py"
  [ -f "$helper" ] || { echo "ERROR: $helper is missing."; return 1; }
  if [ -n "$(host_port_owner "$port" tcp)" ]; then
    echo "ERROR: TCP port $port is busy on this server (a page may already be open; wait until it expires)."
    return 1
  fi
  link=$(vpn_device_link "$vps" "$name") || { echo "ERROR: device '$name' not found."; return 1; }
  label="${link##*#}"
  secret=$(head -c 18 /dev/urandom | od -An -tx1 | tr -d ' \n')
  tmp=$(mktemp /run/vpsforge-vpn-XXXXXX) || return 1
  png=$(mktemp /run/vpsforge-vpnqr-XXXXXX) || { rm -f "$tmp"; return 1; }
  chmod 600 "$tmp" "$png"
  printf '%s' "$link" > "$tmp"
  printf '%s' "$link" | incus exec "$vps" -- qrencode -t png -s 10 -m 2 -o - > "$png" 2>/dev/null
  [ -s "$png" ] || { rm -f "$tmp" "$png"; echo "ERROR: could not make the QR code."; return 1; }
  # open the port only for the page's lifetime, then close it again (runs in the background)
  setsid bash -c '
    iptables -I INPUT -p tcp --dport "$1" -j ACCEPT 2>/dev/null
    python3 "$2" "$3" "$4" "$5" "$1" "$6" "$7" >/dev/null 2>&1
    iptables -D INPUT -p tcp --dport "$1" -j ACCEPT 2>/dev/null
    rm -f "$3" "$4"
  ' _ "$port" "$helper" "$tmp" "$png" "$secret" "$label" "$((minutes * 60))" </dev/null >/dev/null 2>&1 &
  # Give the link only once the page answers, however long Python takes to start on this server.
  # Stop waiting only if the page's server itself ended (it failed to start).
  local server_pid=$!
  while [ -z "$(host_port_owner "$port" tcp)" ]; do
    kill -0 "$server_pid" 2>/dev/null || { echo "ERROR: the page could not be started."; return 1; }
    sleep 0.5
  done
  VPN_SHARE_URL="http://${PUBLIC_IP}:${port}/${secret}/"
  echo "$VPN_SHARE_URL"
}
