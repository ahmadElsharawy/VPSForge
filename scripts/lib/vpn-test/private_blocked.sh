#!/bin/bash
# Succeed only if the VPN behind local SOCKS5 port $1 can NOT reach a private address that the VPN VPS
# itself CAN reach directly: another VPS (the device's own web server), this server's bridge address,
# and the cloud metadata service. A target the VPN VPS cannot reach even directly proves nothing and is skipped.
private_blocked() {
  local sock="$1" target checked=0
  for target in "http://$CIP:18998/" "http://$INCUS_GATEWAY:18997/" "http://169.254.169.254/"; do
    incus exec "$S" -- curl -s -m 5 -o /dev/null "$target" </dev/null || { echo "skip $target (not reachable even directly)"; continue; }
    checked=$((checked + 1))
    if in_c "curl -s -m 8 -o /dev/null --socks5-hostname 127.0.0.1:$sock $target"; then
      echo "LEAK: $target reached through socks port $sock"; return 1
    fi
  done
  [ "$checked" -gt 0 ]   # at least one real private target must have been tried
}
