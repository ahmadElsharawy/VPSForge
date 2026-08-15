#!/bin/bash
# VPSForge v1.0.0 — VPS metadata sync for port forwards and proxy rules.

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

restore_vps_port_forwards_metadata() {
  local name="$1" ip rules proto ext_ip ext_port int_port rule
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0

  # 1. Try to restore from the container's own metadata rules (enables restoration on new servers or if IP changed!)
  rules=$(incus config get "$name" user.vpsforge.port_forwards.rules 2>/dev/null || true)
  if [ -n "$rules" ]; then
    mkdir -p "$(dirname "$PORT_FORWARD_RULES_FILE")"
    touch "$PORT_FORWARD_RULES_FILE"
    IFS=';' read -ra rule_arr <<< "$rules"
    for rule in "${rule_arr[@]}"; do
      [ -n "$rule" ] || continue
      IFS='|' read -r proto ext_ip ext_port int_port <<< "$rule"
      # Skip empty values
      [ -n "$proto" ] && [ -n "$ext_port" ] || continue
      
      # Apply custom rule with the container's current IP
      port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$ip" "$int_port"
      
      # Also add it to our rules file if not already present
      if ! grep -q "${proto}|${ext_ip}|${ext_port}|${ip}|${int_port}" "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
        echo "${proto}|${ext_ip}|${ext_port}|${ip}|${int_port}" >> "$PORT_FORWARD_RULES_FILE"
      fi
    done
    save_iptables
    return 0
  fi

  # 2. Fallback to the original host-rules-file lookup
  [ -f "$PORT_FORWARD_RULES_FILE" ] || return 0
  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ "$int_ip" = "$ip" ] || continue
    port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$PORT_FORWARD_RULES_FILE"
  save_iptables
}
