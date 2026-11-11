#!/bin/bash
# Moves the custom port forwards of one IP to another (and optionally the reverse, for a swap).
remap_port_forwards_ip() {
  local from_a="$1" to_a="$2" from_b="${3:-}" to_b="${4:-}"
  [ -f "$PORT_FORWARD_RULES_FILE" ] || return 0
  local rules proto ext_ip ext_port int_ip int_port new_ip
  rules=$(awk -F'|' -v a="$from_a" -v b="$from_b" '$4 == a || (b != "" && $4 == b)' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)
  [ -n "$rules" ] || return 0

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] || continue
    port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port" 2>/dev/null || true
  done <<< "$rules"

  local tmp_file
  tmp_file=$(mktemp)
  awk -F'|' -v OFS='|' -v a="$from_a" -v na="$to_a" -v b="$from_b" -v nb="$to_b" '
    {
      if ($4 == a) { $4 = na } else if (b != "" && $4 == b) { $4 = nb }
      print
    }' "$PORT_FORWARD_RULES_FILE" > "$tmp_file" && mv -f "$tmp_file" "$PORT_FORWARD_RULES_FILE"

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] || continue
    new_ip="$to_a"
    [ "$int_ip" = "$from_b" ] && [ -n "$from_b" ] && new_ip="$to_b"
    port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$new_ip" "$int_port" 2>/dev/null || true
  done <<< "$rules"
}
