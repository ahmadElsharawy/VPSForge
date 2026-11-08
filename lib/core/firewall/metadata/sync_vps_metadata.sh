#!/bin/bash
sync_vps_metadata() {
  local name="$1" ip pf_count pf_summary pf_rules conf_file proxy_b64
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0

  incus config set "$name" user.vpsforge.ip "$ip" 2>/dev/null || true

  # 1. Sync Port Forwards
  pf_count=0
  pf_summary=""
  pf_rules=""
  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
      [ "$int_ip" = "$ip" ] || continue
      pf_count=$((pf_count+1))
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

  # 2. Sync Proxy Configurations (Caddy)
  conf_file="/etc/caddy/vpsforge/${name}.caddy"
  if [ -f "$conf_file" ]; then
    proxy_b64=$(base64 -w0 "$conf_file" 2>/dev/null || base64 "$conf_file" 2>/dev/null || true)
    incus config set "$name" user.vpsforge.proxy "$proxy_b64" 2>/dev/null || true
  else
    incus config unset "$name" user.vpsforge.proxy 2>/dev/null || true
  fi
}
