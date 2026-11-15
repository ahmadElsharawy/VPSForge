#!/bin/bash
# Check that a subscription URL ($1) gives the three links (base64) and the usage header the apps read.
t_sub() {
  local hdr body
  hdr=$(curl -fsS -m 5 -D - -o /tmp/vpnt-sub.b64 "$1") || return 1
  body=$(base64 -d < /tmp/vpnt-sub.b64); rm -f /tmp/vpnt-sub.b64
  grep -qi '^subscription-userinfo: upload=0; download=[0-9]*; total=[0-9]*; expire=[0-9]*' <<< "$hdr" || return 1
  [ "$(grep -c '^vless://\|^hysteria2://' <<< "$body")" = "3" ] || return 1
  grep -q -- '-REALITY$' <<< "$body" && grep -q -- '-HY2$' <<< "$body" && grep -q -- '-TLS$' <<< "$body"
}
