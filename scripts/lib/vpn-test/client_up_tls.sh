#!/bin/bash
# Start a second Xray client inside the device VPS for the phone's VLESS+TLS link (socks on 127.0.0.1:1082).
# The server's certificate is self-signed, so the client pins its SHA-256 (new Xray has no allowInsecure).
client_up_tls() {
  local id sni pin
  id=$(vpn_device_link "$S" "$1"); id="${id#vless://}"; id="${id%%@*}"
  sni=$(vpn_get_sni "$S" tls)
  pin=$(incus exec "$S" -- sh -c "openssl x509 -in $VPN_GUEST_DIR/tls.crt -outform DER | sha256sum | cut -d' ' -f1" </dev/null)
  printf '{"inbounds":[{"listen":"127.0.0.1","port":1082,"protocol":"socks"}],"outbounds":[{"protocol":"vless","settings":{"vnext":[{"address":"%s","port":%s,"users":[{"id":"%s","encryption":"none"}]}]},"streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"serverName":"%s","pinnedPeerCertSha256":"%s"}}}]}' \
    "$SIP" "$VPN_TLS_INNER_PORT" "$id" "$sni" "$pin" | incus exec "$C" -- sh -c 'cat > /root/t.json'
  in_c 'nohup /usr/local/bin/xray run -c /root/t.json >/root/t.log 2>&1 & sleep 2'
}
