#!/bin/bash
# Restore a VPS container from a backup archive resolving name, port, and domain conflicts.
import_vps_backup() {
  local file_path="$1" name="${2:-}" target_name c new_num new_ip new_port old_ip="" old_port="" hold_name="" caddy_bak="" rc
  _import_validate_backup_file "$file_path" || return 1

  inspect_backup_file "$file_path"

  if [ -z "$name" ]; then
    target_name=$(extract_container_name_from_backup_filename "$file_path")
    if [ -z "$target_name" ]; then
      target_name=$(echo "${index_content:-}" | awk -F': ' '/^name:/{print $2; exit}' | tr -d '"' | tr -d "'" || true)
    fi
  else
    target_name="$name"
  fi

  if incus list -c n --format csv 2>/dev/null | grep -Fxq "$target_name"; then
    local handle_rc=0
    _import_handle_existing_vps || handle_rc=$?
    if [ "$handle_rc" -eq 1 ]; then
      return 1
    elif [ "$handle_rc" -eq 2 ]; then
      return 0
    fi
  fi

  # --- PRE-IMPORT CONFLICT RESOLUTION PHASE ---
  local index_content rules proxy_b64
  index_content=$(cat "${file_path}.info" 2>/dev/null || true)
  [ -n "$index_content" ] || index_content=$(tar -xf "$file_path" backup/index.yaml -O 2>/dev/null || true)
  rules=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.port_forwards\.rules:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "")
  proxy_b64=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.proxy:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "")

  local rules_to_apply=()
  _import_resolve_port_conflicts

  local domains_to_apply=() domains_skipped=()
  local caddy_conflicts_to_remove=()
  local proxy_decoded=""
  _import_resolve_domain_conflicts

  if ! is_valid_vps_name "$target_name"; then
    echo "ERROR: '$target_name' is not a valid VPS name. Use letters, digits and dashes only (no dots, underscores or spaces; not only digits; no dash at the start or end)."
    return 1
  fi

  # Guarded: if the import stops half-way the new VPS is removed completely and the reason is shown.
  if [ -n "$hold_name" ]; then
    hold_vps_for_replace "$target_name" "$hold_name" "$caddy_bak" || { echo "ERROR: could not put '$target_name' aside. Nothing was changed."; return 1; }
  fi
  get_next_available_vps_ip_and_num
  new_num="$NEXT_AVAIL_NUM"; new_ip="$NEXT_AVAIL_IP"; new_port=$(vps_fixed_port "$new_num")
  rm -rf "/opt/vpsforge/.import-caddy-${target_name}"   # a leftover copy of an earlier crashed import must not be restored by this one
  local cleanup_cmd="cleanup_failed_vps $(printf %q "$target_name") $(printf %q "$new_ip") $(printf %q "$new_port"); restore_caddy_after_import $(printf %q "$target_name")"
  if [ -n "$hold_name" ]; then
    cleanup_cmd="$cleanup_cmd; restore_replaced_vps $(printf %q "$target_name") $(printf %q "$hold_name") $(printf %q "$caddy_bak")"
  fi
  run_guarded "$cleanup_cmd" _import_vps_backup_apply
  rc=$?
  if [ -n "$hold_name" ] && [ "$rc" -eq 0 ]; then
    finalize_replaced_vps "$hold_name" "$old_ip" "$old_port" "$caddy_bak"
  fi
  return "$rc"
}
