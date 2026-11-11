#!/bin/bash
# Find the next available numeric index and internal IP for a new VPS.
# Sets NEXT_AVAIL_NUM and NEXT_AVAIL_IP on success.
get_next_available_vps_ip_and_num() {
  local num=1 ip used_ips=() used_nums=() vps_name num_val ssh_port
  local -a all_vps
  local nat_rules
  nat_rules=$(iptables -t nat -L PREROUTING -n 2>/dev/null || true)
  mapfile -t all_vps < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)

  for vps_name in "${all_vps[@]}"; do
    ip=$(incus config get "$vps_name" user.vpsforge.ip 2>/dev/null || true)
    [ -n "$ip" ] && used_ips+=("$ip")
    num_val=$(incus config get "$vps_name" user.vpsforge.num 2>/dev/null || true)
    [ -n "$num_val" ] && used_nums+=("$num_val")
  done

  while :; do
    if [ $((IP_START + num - 1)) -gt 254 ]; then
      echo "ERROR: no free address is left in ${NETWORK_PREFIX}.0/24." >&2
      NEXT_AVAIL_NUM=""; NEXT_AVAIL_IP=""
      return 1
    fi
    ip="${NETWORK_PREFIX}.$((IP_START + num - 1))"
    ssh_port=$((SSH_PORT_BASE + num))
    if [[ " ${used_ips[*]} " != *" $ip "* ]] && \
       [[ " ${used_nums[*]} " != *" $num "* ]] && \
       ! grep -qE "dpt:${ssh_port}([^0-9]|$)" <<< "$nat_rules" && \
       [ -z "$(host_port_owner "$ssh_port" tcp 2>/dev/null)" ]; then
      NEXT_AVAIL_NUM="$num"
      NEXT_AVAIL_IP="$ip"
      return 0
    fi
    num=$((num + 1))
  done
}
