#!/bin/bash
# Delete ONE route (identified by its line number in the VPS's Caddy file),
# including its nested "{ ... }" block. Exact: other routes are never touched.
# If it was the last route, the whole website is unlinked.
#   delete_proxy_route <vps> <line_number>
delete_proxy_route() {
  local vps="${1:?vps}" target_line="${2:?line}"
  local conf="$CADDY_CONF_DIR/${vps}.caddy" backup="${CADDY_CONF_DIR}/${1}.caddy.bak" domain
  [ -f "$conf" ] || return 1

  domain=$(grep -E '^[^[:space:]#].*\{[[:space:]]*$' "$conf" | head -n 1 | awk '{print $1}' | sed 's/[,{]//g')
  cp -f "$conf" "$backup"

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
  # a domain whose last route was just removed must not stay behind as an empty block
  local gone
  while IFS= read -r gone; do
    [ -n "$gone" ] && remove_domain_from_guest_hosts "$vps" "$gone"
  done < <(caddy_drop_empty_sites "$conf")

  if ! grep -q 'reverse_proxy' "$conf"; then
    rm -f "$backup"
    unlink_proxy_domain "$vps" "$domain"
    return 0
  fi

  if caddy_apply_or_rollback "$conf" "$backup"; then
    sync_vps_metadata "$vps"
    return 0
  fi
  sync_vps_metadata "$vps"
  return 1
}
