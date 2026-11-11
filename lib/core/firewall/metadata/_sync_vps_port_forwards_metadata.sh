#!/bin/bash
# Record active port-forward counts, summaries, and rules in container metadata.
_sync_vps_port_forwards_metadata() {
  local name="$1" ip="$2"
  local pf_count=0 pf_summary="" pf_rules=""
  local proto ext_ip ext_port int_ip int_port

  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
      [ "$int_ip" = "$ip" ] || continue
      pf_count=$((pf_count + 1))
      pf_summary+="${proto}:${ext_port}->${int_port} "
      pf_rules+="${proto}|${ext_ip}|${ext_port}|${int_port};"
    done < "$PORT_FORWARD_RULES_FILE"
  fi

  incus config set "$name" user.vpsforge.port_forwards.count "$pf_count" 2>/dev/null || true
  if [ -n "$pf_summary" ]; then
    incus config set "$name" user.vpsforge.port_forwards.summary "${pf_summary% }" 2>/dev/null || true
  else
    incus config unset "$name" user.vpsforge.port_forwards.summary 2>/dev/null || true
  fi

  if [ -n "$pf_rules" ]; then
    incus config set "$name" user.vpsforge.port_forwards.rules "${pf_rules%;}" 2>/dev/null || true
  else
    incus config unset "$name" user.vpsforge.port_forwards.rules 2>/dev/null || true
  fi
}
