#!/bin/bash
# Validate the Caddy configuration and reload it. If it is invalid, put the
# previous file back (or remove the new one) so ONE bad VPS config can never
# break Caddy for every other domain on the server.
#   caddy_apply_or_rollback <conf_file> <backup_file | "">
caddy_apply_or_rollback() {
  local conf_file="${1:?conf_file}" backup_file="${2:-}" output

  if output=$(caddy validate --config "$MAIN_CADDYFILE" 2>&1); then
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
    [ -n "$backup_file" ] && rm -f "$backup_file"
    return 0
  fi

  echo "ERROR: Caddy rejected the new configuration. Changes were reverted."
  echo "$output" | grep -iE 'error|unrecognized|unexpected|ambiguous|parsing' | tail -4 | sed 's/^/  /'
  if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
    mv -f "$backup_file" "$conf_file"
  else
    rm -f "$conf_file"
  fi
  return 1
}
