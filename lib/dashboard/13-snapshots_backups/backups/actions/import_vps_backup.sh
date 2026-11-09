#!/bin/bash

import_vps_backup() {
  local file_path="$1" name="${2:-}" target_name c new_num new_ip new_port
  [ -f "$file_path" ] || { echo "File not found: $file_path"; return 1; }

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
        echo "Deleting current $target_name..."
        local old_ip old_port
        old_ip=$(get_ip "$target_name"); old_port=$(get_port "$old_ip")
        remove_ip "$old_ip"; [ -n "$old_port" ] && remove_port "$old_port"
        [ -n "$old_ip" ] && port_forward_delete_rules_for_ip "$old_ip"
        rm -f "/etc/caddy/vpsforge/${target_name}.caddy"
        incus delete "$target_name" --force >/dev/null 2>&1 || true
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
  rules=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.port_forwards\.rules:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "")
  proxy_b64=$(echo "$index_content" | awk -F': ' '/user\.vpsforge\.proxy:/{print $2; exit}' | tr -d '"' | tr -d "'" || echo "")

  local rules_to_apply=()
  if [ -n "$rules" ]; then
    echo
    echo "Scanning Port Forwarding rules for conflicts..."
    local rules_arr rule proto ext_ip ext_port int_port conflict_line action new_ext_port
    IFS=';' read -ra rules_arr <<< "$rules"
    for rule in "${rules_arr[@]}"; do
      [ -n "$rule" ] || continue
      IFS='|' read -r proto ext_ip ext_port int_port <<< "$rule"
      [ -n "$proto" ] && [ -n "$ext_port" ] || continue
      # The SSH forward (port -> 22) is not restored: the import gives the new VPS its own SSH port,
      # so asking about a conflict with the old VPS's SSH port would be pointless.
      [ "$int_port" = "22" ] && continue
      
      other_vps=$(awk -F'|' -v p="$proto" -v port="$ext_port" '$1 == p && $3 == port { print $4; exit }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null || true)
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
              if ! awk -F'|' -v p="$proto" -v port="$new_ext_port" 'BEGIN { f=0 } $1 == p && $3 == port { f=1; exit } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
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

  local domains_to_apply=()
  local caddy_conflicts_to_remove=()
  local proxy_decoded=""
  if [ -n "$proxy_b64" ] && [ "$proxy_b64" != "-" ]; then
    echo
    echo "Scanning Reverse Proxy (Caddy) domains for conflicts..."
    proxy_decoded=$(echo "$proxy_b64" | base64 -d 2>/dev/null || true)
    local domains_str domain_arr dom conflict_file choice
    domains_str=$(echo "$proxy_decoded" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | head -n 1 | sed 's/{//g' | tr ',' ' ' | xargs)
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
  run_guarded "cleanup_failed_import $(printf %q "$target_name")" _import_vps_backup_apply
}
