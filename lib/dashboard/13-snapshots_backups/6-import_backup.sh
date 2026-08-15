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
        
        conflict_file=$(grep -rl "$dom" "$CADDY_CONF_DIR" 2>/dev/null || true)
        if [ -n "$conflict_file" ]; then
          local conflicting_vps
          conflicting_vps=$(basename "$conflict_file" .caddy)
          echo
          echo "⚠️  DOMAIN CONFLICT detected for Domain [ $dom ]"
          echo "   Domain '$dom' is already linked to VPS '$conflicting_vps'."
          echo "   1) Skip this domain (Default)"
          echo "   2) Takeover (unlink from '$conflicting_vps' and link to '$target_name')"
          read -r -p "   Choice [1-2, Enter=1]: " choice </dev/tty
          choice="${choice:-1}"
          if [ "$choice" = "2" ]; then
            echo "   Will take over domain '$dom' (unlinking from '$conflicting_vps')..."
            caddy_conflicts_to_remove+=("$conflict_file")
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

  # --- EXTRACTION & RESTORE PHASE ---
  incus import "$file_path" "$target_name" >/dev/null 2>&1 &
  local import_pid=$!
  local progress=0
  local spinner="-\\|/"
  local spin_idx=0
  
  while kill -0 $import_pid 2>/dev/null; do
    if [ "$progress" -lt 70 ]; then
      printf "\r[ %3d%% ] Extracting backup file...   " "$progress"
      progress=$((progress + 1))
    else
      printf "\r[  70%% ] Extracting backup file... %c " "${spinner:$spin_idx:1}"
      spin_idx=$(( (spin_idx + 1) % 4 ))
    fi
    sleep 0.5
  done
  wait $import_pid
  if [ $? -ne 0 ]; then
    printf "\r[ FAILED ] Extracting backup file...       \n"
    echo "Import failed."
    return 1
  fi
  printf "\r[  70%% ] Extracting backup file... Done!    \n"

  get_next_available_vps_ip_and_num
  new_num="$NEXT_AVAIL_NUM"
  new_ip="$NEXT_AVAIL_IP"
  new_port=$(vps_fixed_port "$new_num")

  echo "[  75% ] Applying Incus compatibility & basic network..."
  incus config unset "$target_name" volatile.eth0.hwaddr >/dev/null 2>&1 || true
  incus config unset "$target_name" volatile.eth0.host_name >/dev/null 2>&1 || true
  incus config device unset "$target_name" eth0 hwaddr >/dev/null 2>&1 || true
  apply_incus_compatibility_profile "$target_name" >/dev/null 2>&1 || true
  configure_vps_network_device "$target_name" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.ip "$new_ip" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.num "$new_num" >/dev/null 2>&1 || true
  incus config set "$target_name" user.vpsforge.ssh_port "$new_port" >/dev/null 2>&1 || true

  echo "[  80% ] Starting container $target_name..."
  incus start "$target_name" 2>/dev/null || true
  wait_ready "$target_name" >/dev/null 2>&1 || true

  echo "[  85% ] Waiting for network interface (eth0)..."
  wait_guest_eth0 "$target_name" >/dev/null 2>&1 || true

  echo "[  90% ] Applying static IP ($new_ip) & DNS..."
  apply_guest_static_network "$target_name" "$new_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || true
  configure_guest_dns "$target_name" >/dev/null 2>&1 || true

  # Apply resolved Port Forwarding rules
  echo "[  95% ] Restoring port forwarding rules..."
  add_forward_rule "$new_ip" "$new_port" >/dev/null 2>&1 || true
  set_vps_user "$target_name" "root"
  set_vps_password "$target_name" "$ROOT_PASSWORD"
  set_vps_saved_port "$target_name" "$new_port"

  if [ "${#rules_to_apply[@]}" -gt 0 ]; then
    local r proto ext_ip ext_port int_port
    for r in "${rules_to_apply[@]}"; do
      IFS='|' read -r proto ext_ip ext_port int_port <<< "$r"
      port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$new_ip" "$int_port"
      echo "${proto}|${ext_ip}|${ext_port}|${new_ip}|${int_port}" >> "$PORT_FORWARD_RULES_FILE"
    done
    save_iptables
  fi

  # Apply resolved Caddy proxy configurations
  echo "[  98% ] Restoring proxy configurations..."
  if [ "${#domains_to_apply[@]}" -gt 0 ]; then
    local conf
    for conf in "${caddy_conflicts_to_remove[@]}"; do
      rm -f "$conf"
    done
    
    local conf_file="$CADDY_CONF_DIR/${target_name}.caddy"
    mkdir -p "$CADDY_CONF_DIR"
    local joined_domains
    joined_domains=$(local IFS=", "; echo "${domains_to_apply[*]}")
    
    local body
    body=$(echo "$proxy_decoded" | sed -n '/{/,$p')
    echo "$joined_domains $body" > "$conf_file"
    
    sed -i -E "s|reverse_proxy [a-z]*://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:|reverse_proxy http://${new_ip}:|g" "$conf_file" 2>/dev/null || true
    
    caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      systemctl reload-or-restart caddy >/dev/null 2>&1 || true
      echo "   SUCCESS: Linked domains ($joined_domains) restored."
    else
      echo "   ERROR: Caddy validation failed. Restoring proxy cancelled."
      rm -f "$conf_file"
    fi
  fi

  sync_vps_metadata "$target_name" || true
  incus config set "$target_name" user.vpsforge.last_restore "$(date '+%Y-%m-%d %H:%M:%S UTC')" 2>/dev/null || true

  echo "[ 100% ] Success: $target_name restored at $new_ip (SSH Port $new_port)"
}
