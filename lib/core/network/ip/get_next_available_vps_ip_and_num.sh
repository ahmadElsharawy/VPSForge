#!/bin/bash
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
