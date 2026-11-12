#!/bin/bash
# Restore Caddy reverse proxy configuration files and validate against Main Caddyfile.
_import_restore_proxy() {
  [ "${#domains_to_apply[@]}" -gt 0 ] || return 0

  echo "[  98% ] Restoring proxy configurations..."
  # Keep a copy of every Caddy file: if the result does not validate, everything goes back.
  local conf_backup="/opt/vpsforge/.import-caddy-${target_name}" entry loser
  command -v caddy >/dev/null 2>&1 || ensure_caddy_installed || true   # a new host may not have Caddy yet
  rm -rf "$conf_backup"; mkdir -p "$conf_backup"   # a stopped import puts it back (restore_caddy_after_import)
  mkdir -p "$CADDY_CONF_DIR"
  cp -a "$CADDY_CONF_DIR"/. "$conf_backup"/ 2>/dev/null || true
  for entry in "${caddy_conflicts_to_remove[@]}"; do
    caddy_unlink_domain "${entry%%|*}" "${entry#*|}"   # only the taken-over domain leaves the other VPS
  done

  local conf_file="$CADDY_CONF_DIR/${target_name}.caddy" skipped_dom
  mkdir -p "$CADDY_CONF_DIR"
  local joined_domains
  joined_domains=$(local IFS=", "; echo "${domains_to_apply[*]}")

  printf '%s\n' "$proxy_decoded" > "$conf_file"
  for skipped_dom in "${domains_skipped[@]}"; do
    caddy_unlink_domain "$conf_file" "$skipped_dom"
  done
  [ -f "$conf_file" ] && update_vps_proxy_ip "$target_name" "$new_ip"

  caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
    for entry in "${caddy_conflicts_to_remove[@]}"; do   # the VPS that lost a domain must tell the truth too
      loser=$(basename "${entry%%|*}" .caddy)
      sync_vps_metadata "$loser" || true
      tunnel_reconcile_import "$loser" "$(get_ip "$loser")" "$(get_vps_saved_port "$loser")"
    done
    echo "   SUCCESS: Linked domains ($joined_domains) restored."
  else
    echo "   ERROR: Caddy validation failed. Restoring proxy cancelled; nothing was changed."
    rm -f "$CADDY_CONF_DIR"/*.caddy
    cp -a "$conf_backup"/. "$CADDY_CONF_DIR"/ 2>/dev/null || true
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
    rm -rf "$conf_backup"
  fi
}
