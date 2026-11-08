#!/bin/bash
port_forward_rule_exists() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  iptables -t nat -C PREROUTING -p "$protocol" $dest_spec \
    --dport "$external_port" -j DNAT \
    --to-destination "$internal_ip:$internal_port" 2>/dev/null
}
