#!/bin/bash
port_forward_rule_conflicts() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local proto dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  for proto in $(resolve_protocols "$protocol"); do
    if ! iptables -t nat -C PREROUTING -p "$proto" $dest_spec \
      --dport "$external_port" -j DNAT \
      --to-destination "$internal_ip:$internal_port" 2>/dev/null; then
      return 1
    fi
  done
  return 0
}
