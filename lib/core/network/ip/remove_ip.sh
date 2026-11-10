#!/bin/bash
remove_ip() {
  local ip="$1" line
  [ -z "$ip" ] && return
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null |
      awk -v ip="$ip" -v lo="$((SSH_PORT_BASE + 1))" -v hi="$((SSH_PORT_BASE + 900))" '
        {
          port = 0; hit = 0
          for (i = 1; i <= NF; i++) {
            if ($i ~ /^dpt:/) port = substr($i, 5) + 0
            if ($i == ("to:" ip ":22")) hit = 1
          }
          if (hit && port >= lo && port <= hi) { print $1; exit }
        }')
    [ -z "$line" ] && break
    iptables -t nat -D PREROUTING "$line" 2>/dev/null || break
  done
  # The SSH forward also added a FORWARD accept rule: remove it too, or it stays forever.
  while iptables -D FORWARD -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null; do :; done
  while iptables -D FORWARD ! -i incusbr0 -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null; do :; done
  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    local tmpf
    tmpf=$(mktemp)
    awk -F'|' -v target="$ip" -v lo="$((SSH_PORT_BASE + 1))" -v hi="$((SSH_PORT_BASE + 900))" '($4 != target || $5 != 22 || $3 + 0 < lo || $3 + 0 > hi)' "$PORT_FORWARD_RULES_FILE" > "$tmpf" 2>/dev/null || true
    mv -f "$tmpf" "$PORT_FORWARD_RULES_FILE"
  fi
}
