#!/bin/bash
# VPSForge v1.0.0 — IP address queries and collision resolution.

get_ip() {
  local ip
  ip=$(incus config get "$1" user.vpsforge.ip 2>/dev/null || true)
  if [ -n "$ip" ]; then
    echo "$ip"
    return
  fi

  incus query "/1.0/instances/$1/state" 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    network = data.get("network", {})
    eth0 = network.get("eth0", {})
    for addr in eth0.get("addresses", []):
        if addr.get("family") == "inet":
            print(addr.get("address"))
            break
except Exception:
    pass
'
}

NEXT_AVAIL_NUM=1
NEXT_AVAIL_IP=""

get_next_available_vps_ip_and_num() {
  local num=1 ip used_ips=() used_nums=() v n_val ssh_port
  local -a all_vps
  mapfile -t all_vps < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)

  for v in "${all_vps[@]}"; do
    ip=$(incus config get "$v" user.vpsforge.ip 2>/dev/null || true)
    [ -n "$ip" ] && used_ips+=("$ip")
    n_val=$(incus config get "$v" user.vpsforge.num 2>/dev/null || true)
    [ -n "$n_val" ] && used_nums+=("$n_val")
  done

  while :; do
    ip="${NETWORK_PREFIX}.$((IP_START + num - 1))"
    ssh_port=$((SSH_PORT_BASE + num))
    if [[ " ${used_ips[*]} " != *" $ip "* ]] && \
       [[ " ${used_nums[*]} " != *" $num "* ]] && \
       ! iptables -t nat -L PREROUTING -n 2>/dev/null | grep -qE "dpt:${ssh_port}([^0-9]|$)"; then
      NEXT_AVAIL_NUM="$num"
      NEXT_AVAIL_IP="$ip"
      return 0
    fi
    num=$((num + 1))
  done
}

resolve_ip_collisions() {
  local -a all_vps
  mapfile -t all_vps < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' | sort -V || true)
  local seen_ips=() v ip static_ip static_gateway static_netmask

  for v in "${all_vps[@]}"; do
    ip=$(get_ip "$v" 2>/dev/null || true)
    [ -z "$ip" ] || [ "$ip" = "-" ] && continue

    if [[ " ${seen_ips[*]} " == *" $ip "* ]]; then
      echo "WARNING: IP Conflict detected for '$v' on IP $ip. Preserving original identity/port."
      static_ip=$(incus config get "$v" user.vpsforge.ip 2>/dev/null || true)
      if [ -n "$static_ip" ] && is_vps_running "$v"; then
        apply_guest_static_network "$v" "$static_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || true
      fi
    else
      seen_ips+=("$ip")
    fi
  done
}

get_vps_name_by_ip() {
  local target_ip="$1" n ip
  [ -z "$target_ip" ] && return 1
  while read -r n; do
    [ -z "$n" ] && continue
    ip=$(get_ip "$n" 2>/dev/null || true)
    if [ "$ip" = "$target_ip" ]; then
      echo "$n"
      return 0
    fi
  done < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)
  return 1
}
