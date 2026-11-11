#!/bin/bash
# Remove iptables PREROUTING DNAT and FORWARD rules for a port forward.
port_forward_delete_rule() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  iptables -t nat -D PREROUTING -p "$protocol" $dest_spec \
    --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null || true

  if [ -n "$external_ip" ] && [ "$external_ip" != "0.0.0.0" ] && [ "$external_ip" != "any" ]; then
    iptables -t nat -D PREROUTING -p "$protocol" -d "$external_ip" \
      --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null || true   # the older form without the restriction
  fi
  iptables -t nat -D PREROUTING -p "$protocol" \
    --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null || true

  if [ "$external_ip" = "0.0.0.0" ] || [ -z "$external_ip" ] || [ "$external_ip" = "any" ]; then
    iptables -t nat -D PREROUTING -p "$protocol" -d 0.0.0.0 \
      --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null || true
  fi

  iptables -D FORWARD ! -i incusbr0 -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true   # the older rule without the restriction
  iptables -D FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
    -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" -j ACCEPT 2>/dev/null || true
}
