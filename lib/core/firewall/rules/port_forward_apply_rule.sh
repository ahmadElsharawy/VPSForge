#!/bin/bash
port_forward_apply_rule() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  if ! port_forward_rule_exists "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
    iptables -t nat -A PREROUTING -p "$protocol" $dest_spec \
      --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port"
  fi

  iptables -C FORWARD ! -i incusbr0 -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD ! -i incusbr0 -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
      -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

  iptables -C FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
    -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
      -m state --state ESTABLISHED,RELATED -j ACCEPT
}
