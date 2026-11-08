#!/bin/bash
# Warn when a port-forward sends port 80 or 443 straight to a VPS: those packets
# never reach Caddy on the host, so HTTP->HTTPS redirects and ACME HTTP challenges
# go to the VPS instead. Returns 0 when a conflict exists.
proxy_port_conflicts() {
  local rules found=1
  rules=$(iptables -t nat -S PREROUTING 2>/dev/null | grep -E -- '--dport (80|443) .*-j DNAT' || true)
  [ -n "$rules" ] || return 1

  while read -r line; do
    [ -n "$line" ] || continue
    found=0
    echo "  WARNING: port-forward $(echo "$line" | sed -E 's/.*-p ([a-z]+).*--dport ([0-9]+).*--to-destination ([^ ]+).*/\1 \2 -> \3/') bypasses Caddy."
  done <<< "$rules"
  [ "$found" -eq 0 ] && echo "  Fix: delete that port-forward (menu 11) so Caddy can answer on 80/443."
  return "$found"
}
