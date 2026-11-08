#!/bin/bash
remove_port() {
  local port="$1" line
  [ -z "$port" ] && return
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null |
      awk -v p="$port" '
        {
          for (i = 1; i <= NF; i++) {
            if (($i == "dpt:" p || $i ~ ("^dpt:" p "$")) && $0 ~ /to:[0-9.]+:22([^0-9]|$)/) {
              print $1;
              exit;
            }
          }
        }')
    [ -z "$line" ] && break
    iptables -t nat -D PREROUTING "$line" 2>/dev/null || break
  done
  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    local tmpf
    tmpf=$(mktemp)
    awk -F'|' -v p="$port" '!($3 == p && $5 == "22")' "$PORT_FORWARD_RULES_FILE" > "$tmpf" 2>/dev/null || true
    mv -f "$tmpf" "$PORT_FORWARD_RULES_FILE"
  fi
}
