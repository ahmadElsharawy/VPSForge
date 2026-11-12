#!/bin/bash
remove_ip() {
  local ip="$1" line
  [ -z "$ip" ] && return
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null |
      awk -v ip="$ip" -v lo="$((SSH_PORT_BASE + 1))" -v hi="$((SSH_PORT_BASE + 999))" '
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
  # The SSH forward also added a FORWARD accept rule. It has had a few shapes over versions
  # (plain, "! -i incusbr0", and "-m state ..."), so remove EVERY FORWARD rule that accepts
  # port 22 to this ip by its own spec, or a stale one stays forever and could later accept
  # traffic for a different VPS that reuses the ip.
  local spec esc_ip
  esc_ip="${ip//./\\.}"
  while :; do
    spec=$(iptables -S FORWARD 2>/dev/null | grep -m1 -E -- "-d ${esc_ip}/32 .*--dport 22")
    [ -n "$spec" ] || break
    # shellcheck disable=SC2086
    iptables ${spec/-A/-D} 2>/dev/null || break
  done
  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    local tmpf
    tmpf=$(mktemp)
    awk -F'|' -v target="$ip" -v lo="$((SSH_PORT_BASE + 1))" -v hi="$((SSH_PORT_BASE + 999))" '($4 != target || $5 != 22 || $3 + 0 < lo || $3 + 0 > hi)' "$PORT_FORWARD_RULES_FILE" > "$tmpf" 2>/dev/null || true
    mv -f "$tmpf" "$PORT_FORWARD_RULES_FILE"
  fi
}
