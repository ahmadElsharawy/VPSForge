#!/bin/bash
port_forward_remove_rule_from_file() {
  local file="$1" proto="$2" ext_ip="$3" ext_port="$4" int_ip="$5" int_port="$6"
  [ -f "$file" ] || return 0
  local pattern="${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}"
  local tmpf
  tmpf=$(mktemp)
  grep -vFx "$pattern" "$file" > "$tmpf" 2>/dev/null || true
  mv -f "$tmpf" "$file"
}
