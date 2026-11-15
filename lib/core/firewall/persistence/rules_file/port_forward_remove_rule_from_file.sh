#!/bin/bash
# Remove a specific port forward rule from the rules file.
port_forward_remove_rule_from_file() {
  local file="$1" proto="$2" ext_ip="$3" ext_port="$4" int_ip="$5" int_port="$6"
  [ -f "$file" ] || return 0
  local pattern="${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}"
  local tmpf
  tmpf=$(mktemp)
  # grep exits 1 when no line is left (fine) and 2 on a real error (keep the file as it was)
  grep -vFx "$pattern" "$file" > "$tmpf" 2>/dev/null
  if [ $? -le 1 ]; then mv -f "$tmpf" "$file"; else rm -f "$tmpf"; fi
}
