#!/bin/bash
# Make a short-lived page for one device: http://SERVER:<VPN port + 1>/<secret>/ shows one QR code of
# its three links, its permanent subscription link (vpn_sub_url) and "Copy" buttons. The page is a
# folder read by the VPN's permanent web server (vpn_sub_server_ensure); after <minutes> the server
# deletes it. The subscription link keeps working. Sets VPN_SHARE_URL and VPN_SUB_URL, prints the page.
#   vpn_share_link <vps> <device_name> [minutes]
vpn_share_link() {
  local vps="${1:?vps}" name="${2:?name}" minutes="${3:-10}" ext port dir tok secret pd links
  [[ "$minutes" =~ ^[1-9][0-9]*$ ]] || { echo "ERROR: minutes must be a whole number (example: 10)."; return 1; }
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || { echo "ERROR: $vps has no VPN."; return 1; }
  port=$((ext + 1)); dir="$VPN_SUB_DIR/$ext"
  vpn_list_devices "$vps" | awk -F'|' -v n="$name" '$1 == n { f = 1 } END { exit !f }' \
    || { echo "ERROR: device '$name' not found."; return 1; }
  vpn_sub_refresh "$vps" || { echo "ERROR: the subscription server could not be started."; return 1; }
  tok=$(vpn_sub_token "$vps" "$name") || return 1
  [ -s "$dir/subs/$tok" ] || { echo "ERROR: the links of '$name' could not be made."; return 1; }
  links=$(tail -n +3 "$dir/subs/$tok")
  [ -n "${PUBLIC_IP:-}" ] || get_public_ip >/dev/null 2>&1
  [ -n "${PUBLIC_IP:-}" ] || { echo "ERROR: could not find this server's public IP."; return 1; }
  secret=$(head -c 18 /dev/urandom | od -An -tx1 | tr -d ' \n')
  pd="$dir/pages/$secret"
  mkdir -p "$pd" && chmod 700 "$pd" || return 1
  # the QR code holds the three links themselves: one scan adds all three (no download needed)
  printf '%s' "$links" | incus exec "$vps" -- qrencode -t png -s 10 -m 2 -o - > "$pd/qr.png" 2>/dev/null
  [ -s "$pd/qr.png" ] || { rm -rf "$pd"; echo "ERROR: could not make the QR code."; return 1; }
  local scheme="http"
  [ -f "$VPN_SUB_DIR/.tls/cert.pem" ] && scheme="https"   # https when the subscription server serves TLS
  VPN_SUB_URL="${scheme}://${PUBLIC_IP}:${port}/s/${tok}"
  echo "$tok" > "$pd/token"
  echo "$VPN_SUB_URL" > "$pd/url"
  echo $(( $(date +%s) + minutes * 60 )) > "$pd/expires"   # written last: the page exists only once complete
  VPN_SHARE_URL="${scheme}://${PUBLIC_IP}:${port}/${secret}/"
  echo "$VPN_SHARE_URL"
}
