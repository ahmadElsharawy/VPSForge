#!/bin/bash
# Append a port forward rule to the rules file if not already present.
port_forward_append_rule_to_file() {
  local file="$1" proto="$2" ext_ip="$3" ext_port="$4" int_ip="$5" int_port="$6"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file" 2>/dev/null || true
  local entry="${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}"
  if ! grep -Fxq "$entry" "$file" 2>/dev/null; then
    echo "$entry" >> "$file"
  fi
}
