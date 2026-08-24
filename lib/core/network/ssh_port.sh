#!/bin/bash
# VPSForge v1.0.0 — SSH port management.

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

remove_port() {
  local port="$1" line
  [ -z "$port" ] && return
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null |
      awk -v p="$port" '
        {
          for (i = 1; i <= NF; i++) {
            if ($i == "dpt:" p || $i ~ ("^dpt:" p "$")) {
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
    awk -F'|' -v p="$port" '$3 != p' "$PORT_FORWARD_RULES_FILE" > "$tmpf" 2>/dev/null || true
    mv -f "$tmpf" "$PORT_FORWARD_RULES_FILE"
  fi
}

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
  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    local tmpf
    tmpf=$(mktemp)
    awk -F'|' -v target="$ip" '($4 != target || $5 != 22)' "$PORT_FORWARD_RULES_FILE" > "$tmpf" 2>/dev/null || true
    mv -f "$tmpf" "$PORT_FORWARD_RULES_FILE"
  fi
}

vps_fixed_port() {
  local num="$1"
  if [[ "$num" =~ ^[0-9]+$ ]]; then
    echo $((SSH_PORT_BASE + num))
  else
    local hash
    hash=$(echo -n "$num" | cksum | awk '{print $1}')
    echo $((SSH_PORT_BASE + (hash % 900) + 1))
  fi
}

check_fixed_port_available() {
  local name="$1" ip="$2" port="$3" owner_ip
  owner_ip=$(iptables -t nat -L PREROUTING -n 2>/dev/null | awk -v p="$port" '
    $0 ~ "dpt:" p "([^0-9]|$)" {
      if (match($0,/to:([0-9.]+):22/,m)) print m[1]
      exit
    }' 2>/dev/null || true)

  if [ -n "$owner_ip" ] && [ "$owner_ip" != "$ip" ]; then
    echo "ERROR: Required port $port for $name is already assigned to $owner_ip."
    return 1
  fi
  return 0
}
