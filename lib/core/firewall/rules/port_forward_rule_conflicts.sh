#!/bin/bash
# Check if the requested port forwarding rule already exists in iptables.
port_forward_rule_conflicts() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local proto

  for proto in $(resolve_protocols "$protocol"); do
    if ! port_forward_rule_exists "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
      return 1
    fi
  done
  return 0
}
