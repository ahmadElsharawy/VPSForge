#!/bin/bash
# Start a Hysteria2 client inside the device VPS for the phone's link (socks on 127.0.0.1:1081).
# The client program is copied from the VPN VPS (same version, no download).
client_up_hy() {
  local id sni
  id=$(vpn_device_link "$S" "$1"); id="${id#vless://}"; id="${id%%@*}"
  sni=$(vpn_get_sni "$S" hy)
  if ! in_c 'test -x /usr/local/bin/hysteria'; then
    incus file pull "$S/usr/local/bin/hysteria" /tmp/vpnt-hysteria >/dev/null 2>&1 || return 1
    incus file push --mode 0755 /tmp/vpnt-hysteria "$C/usr/local/bin/hysteria" >/dev/null 2>&1; rm -f /tmp/vpnt-hysteria
  fi
  printf 'server: %s:%s\nauth: %s\ntls:\n  sni: %s\n  insecure: true\nsocks5:\n  listen: 127.0.0.1:1081\n' \
    "$SIP" "$VPN_HY_INNER_PORT" "$id" "$sni" | incus exec "$C" -- sh -c 'cat > /root/h.yaml'
  in_c 'pkill -x hysteria; nohup /usr/local/bin/hysteria client -c /root/h.yaml >/root/h.log 2>&1 & sleep 3'
}
