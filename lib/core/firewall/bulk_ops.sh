#!/bin/bash
# VPSForge v1.0.0 — Bulk port forward operations.

port_forward_save_rules_to_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  port_forward_auto_sync_active_rules "$file"
  echo "Rules saved to $file."
}

port_forward_load_rules_from_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo "No rules file found at $file."; return 1; }

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$file"
  save_iptables
  echo "Rules loaded from $file."
}

port_forward_delete_all_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo "No rules file found."; return; }

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$file"

  > "$file"
  save_iptables
  echo "All port forward rules deleted."
}

port_forward_disable_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo "No rules file."; return; }

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] || continue
    port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$file"

  save_iptables
  echo "Port forward rules disabled (kept in file)."
}

port_forward_enable_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  port_forward_load_rules_from_file "$file"
  echo "Port forward rules re-enabled."
}

port_forward_delete_rules_for_ip() {
  local target_ip="$1" file="${2:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || return 0

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] || continue
    if [ "$int_ip" = "$target_ip" ]; then
      port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
    fi
  done < "$file"

  local tmpf
  tmpf=$(mktemp)
  awk -F'|' -v ip="$target_ip" '$4 != ip' "$file" > "$tmpf" 2>/dev/null || true
  mv -f "$tmpf" "$file"
  save_iptables
}
