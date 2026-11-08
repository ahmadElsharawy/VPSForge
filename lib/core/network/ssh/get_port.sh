#!/bin/bash
get_port() {
  local ip="$1" port=""
  [ -z "$ip" ] && return

  # 1. Query active iptables PREROUTING table
  port=$(iptables -t nat -L PREROUTING -n 2>/dev/null |
    awk -v ip="$ip" '
      $0 ~ ("to:" ip ":22([^0-9]|$)") {
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^dpt:[0-9]+$/) {
            sub(/^dpt:/, "", $i);
            print $i;
            exit;
          }
        }
      }')

  # 2. Fallback to saved port forwards file
  if [ -z "$port" ] && [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    port=$(awk -F'|' -v target="$ip" '$4 == target && $5 == "22" { print $3; exit }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null || true)
  fi

  # 3. Fallback to container metadata
  if [ -z "$port" ]; then
    local name
    name=$(get_vps_name_by_ip "$ip" 2>/dev/null || true)
    [ -n "$name" ] && port=$(get_vps_saved_port "$name" 2>/dev/null || true)
  fi

  echo "$port"
}
