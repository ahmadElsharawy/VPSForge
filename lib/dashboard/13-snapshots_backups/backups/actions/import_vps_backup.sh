#!/bin/bash

import_vps_backup() {
  local file_path="$1" name="${2:-}" target_name c new_num new_ip new_port old_ip="" old_port="" hold_name="" caddy_bak="" rc
  [ -f "$file_path" ] || { echo "File not found: $file_path"; return 1; }

  # A damaged backup is useless and would only waste disk: say so and delete it (nothing else is touched).
  if command -v zstd >/dev/null 2>&1 && ! tar -tf "$file_path" >/dev/null 2>&1; then
    if [[ "$file_path" == "${BACKUP_DIR:-/opt/vpsforge-backups}"/* ]]; then
      echo "ERROR: the backup file is damaged or unreadable. It was deleted: $(basename "$file_path")"
      rm -f "$file_path" "${file_path}.info"
    else
      echo "ERROR: the file looks damaged or unreadable. It is outside the backup folder, so it was NOT deleted: $file_path"
    fi
    return 1
  fi

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
    echo "WARNING: Instance '$target_name' currently exists on this server."
    echo "0) Cancel (Default)"
    echo "1) Import under a different name"
    echo "2) Overwrite / Replace current '$target_name' with backup"
    read -r -p "Choice [0=Cancel, 1-2, Enter=0]: " c
    c="${c:-0}"
    case "$c" in
      1)
        local auto_next suffix_num=1 base_prefix="$target_name"
        if [[ "$target_name" =~ -[0-9]+$ ]]; then
          base_prefix="${target_name%-*}"
          suffix_num="${target_name##*-}"
          suffix_num=$((suffix_num + 1))
        fi
        auto_next="${base_prefix}-${suffix_num}"
        while incus list -c n --format csv 2>/dev/null | grep -Fxq "$auto_next"; do
          suffix_num=$((suffix_num + 1))
          auto_next="${base_prefix}-${suffix_num}"
        done
        read -r -p "Enter new VPS container name [default: $auto_next]: " custom_target </dev/tty
        custom_target="${custom_target:-$auto_next}"
        if incus list -c n --format csv 2>/dev/null | grep -Fxq "$custom_target"; then
          echo "ERROR: Instance '$custom_target' currently exists on this server. Please choose another name."
          return 1
        else
          target_name="$custom_target"
        fi
        ;;
      2)
        read -r -p "This DELETES the current '$target_name' and replaces it with the backup. Type YES to continue: " c </dev/tty || c=""
        [ "$c" = "YES" ] || { echo "Import cancelled."; return 0; }
        echo "Putting the current $target_name aside (it is deleted only after the import succeeds)..."
        old_ip=$(get_ip "$target_name"); old_port=$(get_port "$old_ip")
        hold_name="${target_name}-replaced-$$"
        caddy_bak="/opt/vpsforge/.replaced-${hold_name}.caddy"
        ;;
      *)
        echo "Import cancelled."
        return 0
        ;;
    esac
  fi

  # --- PRE-IMPORT CONFLICT RESOLUTION PHASE ---
  local index_content rules proxy_b64
  index_content=$(cat "${file_path}.info" 2>/dev/null || true)
  [ -n "$index_content" ] || index_content=$(tar -xf "$file_path" backup/index.yaml -O 2>/dev/null || true)
  rules=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.port_forwards\.rules:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "")
  proxy_b64=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.proxy:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "")

  local rules_to_apply=()
  if [ -n "$rules" ]; then
    echo
    echo "Scanning Port Forwarding rules for conflicts..."
    local rules_arr rule proto ext_ip ext_port int_port conflict_line action new_ext_port host_check
    IFS=';' read -ra rules_arr <<< "$rules"
    for rule in "${rules_arr[@]}"; do
      [ -n "$rule" ] || continue
      IFS='|' read -r proto ext_ip ext_port int_port <<< "$rule"
      [ -n "$proto" ] && [ -n "$ext_port" ] || continue
      is_valid_port_forward_rule "$proto" "$ext_ip" "$ext_port" "$int_port" || { echo "Skipped unsafe or invalid forward rule: $rule"; continue; }
      # The SSH forward (port -> 22) is not restored: the import gives the new VPS its own SSH port,
      # so asking about a conflict with the old VPS's SSH port would be pointless.
      [ "$int_port" = "22" ] && continue
      
      other_vps=$(awk -F'|' -v p="$proto" -v port="$ext_port" -v oldip="$old_ip" '$1 == p && $3 == port && $4 != oldip { print $4; exit }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null || true)
      if [ -n "$other_vps" ]; then
        echo
        echo "⚠️  PORT FORWARD CONFLICT detected for Rule [ $proto:$ext_port -> $int_port ]"
        echo "   External port $ext_port ($proto) is already used by VPS IP $other_vps."
        echo "   1) Change external port"
        echo "   2) Skip this rule (Default)"
        read -r -p "   Choice [1-2, Enter=2]: " action </dev/tty
        action="${action:-2}"
        if [ "$action" = "1" ]; then
          while :; do
            read -r -p "   Enter new external port for $proto: " new_ext_port </dev/tty
            if [[ "$new_ext_port" =~ ^[0-9]+$ ]] && [ "$new_ext_port" -gt 0 ] && [ "$new_ext_port" -lt 65536 ]; then
              host_check=0
              port_forward_host_conflict "$new_ext_port" "$proto" >/dev/null 2>&1 || host_check=$?
              if ! is_valid_port_forward_rule "$proto" "$ext_ip" "$new_ext_port" "$int_port"; then
                echo "   ERROR: that port is not allowed (22, 80 and 443 are reserved)."
              elif [ "$host_check" -eq 1 ]; then
                echo "   ERROR: the host itself uses port $new_ext_port. Try another one."
              elif ! awk -F'|' -v p="$proto" -v port="$new_ext_port" -v oldip="$old_ip" 'BEGIN { f=0 } $1 == p && $3 == port && $4 != oldip { f=1; exit } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
                ext_port="$new_ext_port"
                break
              else
                echo "   ERROR: Port $new_ext_port is also occupied. Try another one."
              fi
            else
              echo "   ERROR: Invalid port number. Must be 1-65535."
            fi
          done
          rules_to_apply+=("${proto}|${ext_ip}|${ext_port}|${int_port}")
        else
          echo "   Skipped rule [ $proto:$ext_port -> $int_port ]."
        fi
      else
        rules_to_apply+=("${proto}|${ext_ip}|${ext_port}|${int_port}")
      fi
    done
  fi

  local domains_to_apply=() domains_skipped=()
  local caddy_conflicts_to_remove=()
  local proxy_decoded=""
  if [ -n "$proxy_b64" ] && [ "$proxy_b64" != "-" ]; then
    echo
    echo "Scanning Reverse Proxy (Caddy) domains for conflicts..."
    proxy_decoded=$(echo "$proxy_b64" | base64 -d 2>/dev/null || true)
    local domains_str domain_arr dom conflict_file choice
    domains_str=$(caddy_site_domains <<< "$proxy_decoded" | sort -u | tr '\n' ' ')
    if [ -n "$domains_str" ]; then
      IFS=' ' read -ra domain_arr <<< "$domains_str"
      for dom in "${domain_arr[@]}"; do
        dom=${dom%,}
        [ -n "$dom" ] || continue
        
        local conflicting_vps
        conflicting_vps=$(domain_used_by_other_vps "$dom" "$target_name" || true)
        conflict_file=""
        [ -n "$conflicting_vps" ] && conflict_file="$CADDY_CONF_DIR/${conflicting_vps}.caddy"
        if [ -n "$conflict_file" ]; then
          echo
          echo "⚠️  DOMAIN CONFLICT detected for Domain [ $dom ]"
          echo "   Domain '$dom' is already linked to VPS '$conflicting_vps'."
          echo "   1) Skip this domain (Default)"
          echo "   2) Takeover (unlink from '$conflicting_vps' and link to '$target_name')"
          read -r -p "   Choice [1-2, Enter=1]: " choice </dev/tty
          choice="${choice:-1}"
          if [ "$choice" = "2" ]; then
            echo "   Will take over domain '$dom' (unlinking from '$conflicting_vps')..."
            caddy_conflicts_to_remove+=("$conflict_file|$dom")
            domains_to_apply+=("$dom")
          else
            echo "   Skipped domain '$dom'."
            domains_skipped+=("$dom")
          fi
        else
          domains_to_apply+=("$dom")
        fi
      done
    fi
  fi

  if ! [[ "$target_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
    echo "ERROR: '$target_name' is not a valid VPS name (letters, digits, dots, dashes, underscores)."
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
