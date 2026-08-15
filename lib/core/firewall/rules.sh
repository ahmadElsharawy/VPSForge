#!/bin/bash
# VPSForge v1.0.0 — Port forward rule apply and delete.

port_forward_apply_rule() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  if ! port_forward_rule_exists "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
    iptables -t nat -A PREROUTING -p "$protocol" $dest_spec \
      --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port"
  fi

  iptables -C FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
      -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

  iptables -C FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
    -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
      -m state --state ESTABLISHED,RELATED -j ACCEPT
}

port_forward_delete_rule() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  iptables -t nat -D PREROUTING -p "$protocol" $dest_spec \
    --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null || true

  if [ "$external_ip" = "0.0.0.0" ] || [ -z "$external_ip" ]; then
    iptables -t nat -D PREROUTING -p "$protocol" -d 0.0.0.0 \
      --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null || true
  fi

  iptables -D FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
    -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
}
