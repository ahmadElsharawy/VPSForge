#!/bin/bash
# Configure and start Xray client inside the test container for a device.
client_up() {
  local link id q pbk sid sni
  link=$(vpn_device_link "$S" "$1")
  id="${link#vless://}"; id="${id%%@*}"; q="${link#*\?}"; q="${q%%#*}"
  pbk=$(tr '&' '\n' <<< "$q" | sed -n 's/^pbk=//p'); sid=$(tr '&' '\n' <<< "$q" | sed -n 's/^sid=//p'); sni=$(tr '&' '\n' <<< "$q" | sed -n 's/^sni=//p')
  in_c 'pkill -x xray; sleep 1' >/dev/null 2>&1
  printf '{"inbounds":[{"listen":"127.0.0.1","port":1080,"protocol":"socks"}],"outbounds":[{"protocol":"vless","settings":{"vnext":[{"address":"%s","port":%s,"users":[{"id":"%s","flow":"xtls-rprx-vision","encryption":"none"}]}]},"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"serverName":"%s","fingerprint":"chrome","publicKey":"%s","shortId":"%s"}}}]}' \
    "$SIP" "$PORT" "$id" "$sni" "$pbk" "$sid" | incus exec "$C" -- sh -c 'cat > /root/c.json'
  in_c 'nohup /usr/local/bin/xray run -c /root/c.json >/root/x.log 2>&1 & sleep 2'
}
