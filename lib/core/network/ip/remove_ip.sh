#!/bin/bash
remove_ip() {
  local ip="$1" line
  [ -z "$ip" ] && return
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null |
      awk -v ip="$ip" '
        {
          for (i = 1; i <= NF; i++) {
            if ($i == ("to:" ip ":22") || $i ~ ("^to:" ip ":22$")) {
              print $1;
              exit;
            }
          }
        }')
    [ -z "$line" ] && break
    iptables -t nat -D PREROUTING "$line" 2>/dev/null || break
  done
  # The SSH forward also added a FORWARD accept rule: remove it too, or it stays forever.
  while iptables -D FORWARD -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null; do :; done
  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    local tmpf
    tmpf=$(mktemp)
    awk -F'|' -v target="$ip" '($4 != target || $5 != 22)' "$PORT_FORWARD_RULES_FILE" > "$tmpf" 2>/dev/null || true
    mv -f "$tmpf" "$PORT_FORWARD_RULES_FILE"
  fi
}
