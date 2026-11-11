#!/bin/bash
# Remove a reverse_proxy directive and its nested block at target_line from a Caddy config file.
#   _caddy_remove_route_at_line <conf_file> <target_line>
_caddy_remove_route_at_line() {
  local conf="$1" target_line="$2"
  local -a new_lines=()
  local deleting=0 brace_depth=0 open_b close_b n=0 line
  while IFS= read -r line; do
    n=$((n + 1))
    if [ $deleting -eq 1 ]; then
      open_b=$(echo "$line" | tr -cd '{' | wc -c)
      close_b=$(echo "$line" | tr -cd '}' | wc -c)
      brace_depth=$((brace_depth + open_b - close_b))
      [ $brace_depth -le 0 ] && deleting=0
      continue
    fi
    if [ "$n" -eq "$target_line" ]; then
      open_b=$(echo "$line" | tr -cd '{' | wc -c)
      close_b=$(echo "$line" | tr -cd '}' | wc -c)
      brace_depth=$((open_b - close_b))
      [ $brace_depth -gt 0 ] && deleting=1
      continue
    fi
    new_lines+=("$line")
  done < "$conf"
  printf '%s\n' "${new_lines[@]}" > "$conf"
}
