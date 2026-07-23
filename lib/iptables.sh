#!/bin/bash
# VPSForge — Port-forwarding rule management via iptables.

# ── Protocol Helper ──────────────────────────────────────────────────────────

# Resolves "both" → "tcp udp"; otherwise returns the protocol as-is.
# Usage: for proto in $(resolve_protocols "$protocol"); do ...; done
# Resolves "both" → "tcp udp"; otherwise returns the protocol as-is.
# Usage: for proto in $(resolve_protocols "$protocol"); do ...; done
resolve_protocols() {
  case "$1" in
    both) echo "tcp udp";;
    *)    echo "$1";;
  esac
}

# ── Destination IP Helper ───────────────────────────────────────────────────
# If external_ip is 0.0.0.0, empty, or "any", match all non-bridge incoming interfaces (! -i incusbr0).
_build_dest_spec() {
  local ext_ip="${1:-}"
  if [ -n "$ext_ip" ] && [ "$ext_ip" != "0.0.0.0" ] && [ "$ext_ip" != "any" ]; then
    echo "-d $ext_ip"
  else
    echo "! -i incusbr0"
  fi
}

# ── Purge Invalid Legacy Rules ───────────────────────────────────────────────
purge_invalid_dnat_rules() {
  local rule
  while read -r rule; do
    [ -n "$rule" ] || continue
    iptables -t nat -D PREROUTING $rule 2>/dev/null || true
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-d 0\.0\.0\.0' | sed 's/^-A PREROUTING //' || true)

  while read -r rule; do
    [ -n "$rule" ] || continue
    if [[ "$rule" != *"incusbr0"* ]] && [[ "$rule" != *"-d "* ]]; then
      iptables -t nat -D PREROUTING $rule 2>/dev/null || true
    fi
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-j DNAT' | sed 's/^-A PREROUTING //' || true)
}

# ── Firewall Architecture & Inter-VPS Isolation ─────────────────────────────

setup_inter_vps_isolation() {
  [ -n "${NETWORK_PREFIX:-}" ] || return 0
  local subnet="${NETWORK_PREFIX}.0/24"

  # Load kernel module and enable bridge netfilter
  modprobe br_netfilter 2>/dev/null || true
  sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>&1 || true

  # 1. Outbound NAT (VPS -> Internet)
  iptables -t nat -C POSTROUTING -s "$subnet" ! -d "$subnet" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$subnet" ! -d "$subnet" -j MASQUERADE

  # 2. Hairpin NAT (VPS -> Public IP:Port -> VPS)
  iptables -t nat -C POSTROUTING -s "$subnet" -d "$subnet" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$subnet" -d "$subnet" -j MASQUERADE

  # 3. FORWARD: ALLOW Established / Related connections
  iptables -C FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  # 4. FORWARD: ALLOW all DNAT-forwarded traffic (WAN -> Forwarded Port -> Container)
  iptables -C FORWARD -m conntrack --ctstate DNAT -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 2 -m conntrack --ctstate DNAT -j ACCEPT

  # 5. FORWARD: ALLOW VPS -> Internet outbound traffic
  iptables -C FORWARD -i incusbr0 ! -o incusbr0 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 3 -i incusbr0 ! -o incusbr0 -j ACCEPT

  # 6. FORWARD: ALLOW VPS -> Gateway (Host IP) for DNS/DHCP
  if [ -n "${INCUS_GATEWAY:-}" ]; then
    iptables -C FORWARD -i incusbr0 -s "$subnet" -d "$INCUS_GATEWAY" -j ACCEPT 2>/dev/null || \
      iptables -I FORWARD 4 -i incusbr0 -s "$subnet" -d "$INCUS_GATEWAY" -j ACCEPT
  fi

  # 7. FORWARD: DENY Inter-VPS communication (Container A -> Container B = DENY)
  iptables -C FORWARD -i incusbr0 -o incusbr0 -j DROP 2>/dev/null || \
    iptables -A FORWARD -i incusbr0 -o incusbr0 -j DROP

  iptables -C FORWARD -s "$subnet" -d "$subnet" -j DROP 2>/dev/null || \
    iptables -A FORWARD -s "$subnet" -d "$subnet" -j DROP

  # Purge any old invalid -d 0.0.0.0 DNAT rules
  purge_invalid_dnat_rules

  save_iptables
}

# ── Rule Detection ───────────────────────────────────────────────────────────

port_forward_rule_exists() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  iptables -t nat -C PREROUTING -p "$protocol" $dest_spec \
    --dport "$external_port" -j DNAT \
    --to-destination "$internal_ip:$internal_port" 2>/dev/null
}

port_forward_rule_conflicts() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local proto dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  for proto in $(resolve_protocols "$protocol"); do
    if iptables -t nat -C PREROUTING -p "$proto" $dest_spec \
      --dport "$external_port" -j DNAT \
      --to-destination "$internal_ip:$internal_port" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# ── Apply / Delete iptables Rules ────────────────────────────────────────────

port_forward_apply_rule() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  if ! port_forward_rule_exists "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
    iptables -t nat -A PREROUTING -p "$protocol" $dest_spec \
      --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port"
  fi

  iptables -C FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
      -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

  iptables -C FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
    -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
      -m state --state ESTABLISHED,RELATED -j ACCEPT
}

port_forward_delete_rule() {
  local protocol="$1" external_ip="$2" external_port="$3"
  local internal_ip="$4" internal_port="$5"
  local dest_spec
  dest_spec=$(_build_dest_spec "$external_ip")

  iptables -t nat -D PREROUTING -p "$protocol" $dest_spec \
    --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null || true

  if [ "$external_ip" = "0.0.0.0" ] || [ -z "$external_ip" ]; then
    iptables -t nat -D PREROUTING -p "$protocol" -d 0.0.0.0 \
      --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null || true
  fi

  iptables -D FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" \
    -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" \
    -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
}

# ── File-Based Rule Persistence ──────────────────────────────────────────────

port_forward_rule_key() {
  printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5"
}

port_forward_rule_file_exists() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] && [ -s "$file" ]
}

port_forward_append_rule_to_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  local protocol="$2" external_ip="$3" external_port="$4"
  local internal_ip="$5" internal_port="$6"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  local key
  key=$(port_forward_rule_key "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port")
  if ! grep -Fxq "$key" "$file" 2>/dev/null; then
    printf '%s\n' "$key" >> "$file"
  fi
}

port_forward_remove_rule_from_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  local protocol="$2" external_ip="$3" external_port="$4"
  local internal_ip="$5" internal_port="$6"

  [ -f "$file" ] || return 0
  local key
  key=$(port_forward_rule_key "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port")
  grep -Fvx "$key" "$file" 2>/dev/null > "${file}.tmp" || true
  mv "${file}.tmp" "$file"
}

port_forward_clear_rules_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  mkdir -p "$(dirname "$file")"
  : > "$file"
}

# ── Container Metadata Port Forward Sync ─────────────────────────────────────

sync_vps_port_forwards_metadata() {
  local name="$1" ip rules=""
  [ -n "$name" ] || return 0
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0

  if [ -f "$PORT_FORWARD_RULES_FILE" ]; then
    rules=$(grep "|${ip}|" "$PORT_FORWARD_RULES_FILE" 2>/dev/null | tr '\n' ';' || true)
  fi

  incus config set "$name" user.vpsforge.portforwards "$rules" 2>/dev/null || true
}

restore_vps_port_forwards_metadata() {
  local name="$1" target_ip="${2:-}" rules rule protocol ext_ip ext_port int_ip int_port rule_list
  [ -n "$name" ] || return 0
  [ -n "$target_ip" ] || target_ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$target_ip" ] || return 0

  rules=$(incus config get "$name" user.vpsforge.portforwards 2>/dev/null || true)
  [ -n "$rules" ] || return 0

  IFS=';' read -ra rule_list <<< "$rules"
  for rule in "${rule_list[@]}"; do
    [ -n "$rule" ] || continue
    IFS='|' read -r protocol ext_ip ext_port int_ip int_port <<< "$rule"
    [ -n "$protocol" ] || continue

    local conflict
    conflict=$(awk -v p="$protocol" -v eip="$ext_ip" -v eport="$ext_port" -v intip="$target_ip" -F'|' '
      $1 == p && $2 == eip && $3 == eport && $4 != intip { print $4; exit }
    ' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)

    if [ -n "$conflict" ]; then
      local conflict_vps
      conflict_vps=$(get_vps_name_by_ip "$conflict" 2>/dev/null || true)
      [ -n "$conflict_vps" ] && conflict_vps="$conflict_vps ($conflict)" || conflict_vps="$conflict"
      
      echo ""
      echo "WARNING: External port $ext_port ($protocol) is already forwarded to $conflict_vps."
      echo "1) Skip this port for $name"
      echo "2) Steal this port (remove from $conflict_vps, give to $name)"
      echo "3) Enter a different external port for $name"
      local choice new_ext_port
      while :; do
        read -r -p "Choice [1-3]: " choice
        case "$choice" in
          1) continue 2 ;; # skip this rule entirely
          2)
            port_forward_cli delete "$protocol" "$ext_ip" "$ext_port" "$conflict" "$int_port" >/dev/null 2>&1
            break
            ;;
          3)
            read -r -p "New External Port: " new_ext_port
            if [[ "$new_ext_port" =~ ^[0-9]+$ ]]; then
              ext_port="$new_ext_port"
              break
            else
              echo "Invalid port."
            fi
            ;;
        esac
      done
    fi

    port_forward_apply_rule "$protocol" "$ext_ip" "$ext_port" "$target_ip" "$int_port"
    port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" "$protocol" "$ext_ip" "$ext_port" "$target_ip" "$int_port"
  done
  save_iptables
}

# ── Bulk Rule Operations ────────────────────────────────────────────────────

port_forward_save_rules_to_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  mkdir -p "$(dirname "$file")"
  cp "$PORT_FORWARD_RULES_FILE" "$file" 2>/dev/null || true
  [ -f "$file" ] || : > "$file"
}

port_forward_load_rules_from_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo "Rule file not found: $file"; return 1; }

  local protocol external_ip external_port internal_ip internal_port
  while IFS='|' read -r protocol external_ip external_port internal_ip internal_port; do
    [ -n "$protocol" ] || continue
    [ "$protocol" != "#" ] || continue
    [[ "$protocol" =~ ^(tcp|udp)$ ]] || continue
    if ! port_forward_rule_exists "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
      port_forward_apply_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
    fi
  done < "$file"
  save_iptables
  echo "Loaded port-forward rules from $file"
}

port_forward_delete_rules_for_ip() {
  local target_ip="$1"
  [ -n "$target_ip" ] || return 0

  local file="${2:-$PORT_FORWARD_RULES_FILE}"
  if [ -f "$file" ]; then
    local protocol external_ip external_port internal_ip internal_port
    while IFS='|' read -r protocol external_ip external_port internal_ip internal_port; do
      [ -n "$protocol" ] || continue
      [ "$protocol" != "#" ] || continue
      if [ "$internal_ip" = "$target_ip" ]; then
        port_forward_delete_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$file" "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      fi
    done < "$file"
    save_iptables
  fi
}

port_forward_delete_all_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  if [ -f "$file" ]; then
    while IFS='|' read -r protocol external_ip external_port internal_ip internal_port; do
      [ -n "$protocol" ] || continue
      [ "$protocol" != "#" ] || continue
      [[ "$protocol" =~ ^(tcp|udp)$ ]] || continue
      port_forward_delete_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
    done < "$file"
  fi
  port_forward_clear_rules_file "$file"
  save_iptables
  echo "Deleted all stored port-forward rules"
}

port_forward_disable_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  if [ -f "$file" ]; then
    while IFS='|' read -r protocol external_ip external_port internal_ip internal_port; do
      [ -n "$protocol" ] || continue
      [ "$protocol" != "#" ] || continue
      [[ "$protocol" =~ ^(tcp|udp)$ ]] || continue
      port_forward_delete_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
    done < "$file"
  fi
  save_iptables
  echo "Disabled active port-forward rules"
}

port_forward_enable_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  port_forward_load_rules_from_file "$file"
}

# ── Display ──────────────────────────────────────────────────────────────────

port_forward_list_rules() {
  echo "Configured Port-Forward Rules:"
  if [ -f "$PORT_FORWARD_RULES_FILE" ] && [ -s "$PORT_FORWARD_RULES_FILE" ]; then
    local idx=1 protocol ext_ip ext_port int_ip int_port vps_name proto_upper target_disp
    while IFS='|' read -r protocol ext_ip ext_port int_ip int_port; do
      [ -n "$protocol" ] || continue
      [ "$protocol" != "#" ] || continue
      vps_name=$(get_vps_name_by_ip "$int_ip" 2>/dev/null || true)
      target_disp="$int_ip"
      [ -n "$vps_name" ] && target_disp="$vps_name ($int_ip)"
      proto_upper=$(echo "$protocol" | tr '[:lower:]' '[:upper:]')
      printf "  %2d) %-4s %s:%s -> %s:%s\n" "$idx" "$proto_upper" "${ext_ip:-0.0.0.0}" "$ext_port" "$target_disp" "$int_port"
      idx=$((idx+1))
    done < "$PORT_FORWARD_RULES_FILE"
  else
    echo "No saved port-forward rules found."
  fi
}

get_port_forward_rule_by_index() {
  local target_idx="$1" idx=1 line
  [ -f "$PORT_FORWARD_RULES_FILE" ] || return 1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [[ "$line" =~ ^# ]] && continue
    if [ "$idx" -eq "$target_idx" ]; then
      echo "$line"
      return 0
    fi
    idx=$((idx+1))
  done < "$PORT_FORWARD_RULES_FILE"
  return 1
}

count_port_forward_rules() {
  [ -f "$PORT_FORWARD_RULES_FILE" ] || { echo "0"; return; }
  grep -cv '^\s*$' "$PORT_FORWARD_RULES_FILE" 2>/dev/null || echo "0"
}

port_forward_status() {
  echo "Active NAT port-forward rules:"
  iptables -t nat -S 2>/dev/null | grep -E 'DNAT --to-destination' || echo "No active DNAT port-forward rules found."
}

# ── CLI Interface ────────────────────────────────────────────────────────────
# Deduplicated: uses resolve_protocols() to handle "both" → tcp + udp
# in a single loop instead of repeating the pattern in each action.

port_forward_cli() {
  local action="${1:-}"
  local protocol external_ip external_port internal_ip internal_port
  local target_file="$PORT_FORWARD_RULES_FILE"

  case "$action" in
    add)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward add <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}" external_port="${4:-}" internal_ip="${5:-}" internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
      [[ "$external_port" =~ ^[0-9]+$ ]]    || { echo "External port must be numeric."; return 1; }
      [[ "$internal_port" =~ ^[0-9]+$ ]]    || { echo "Internal port must be numeric."; return 1; }

      if port_forward_rule_conflicts "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
        echo "Rule already exists for $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
        return 0
      fi

      local proto target_vps
      for proto in $(resolve_protocols "$protocol"); do
        port_forward_apply_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      done
      save_iptables
      target_vps=$(get_vps_name_by_ip "$internal_ip" 2>/dev/null || true)
      [ -n "$target_vps" ] && sync_vps_port_forwards_metadata "$target_vps"
      echo "Port forward applied: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;

    edit)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward edit <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}" external_port="${4:-}" internal_ip="${5:-}" internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
      [[ "$external_port" =~ ^[0-9]+$ ]]    || { echo "External port must be numeric."; return 1; }
      [[ "$internal_port" =~ ^[0-9]+$ ]]    || { echo "Internal port must be numeric."; return 1; }

      local proto target_vps
      for proto in $(resolve_protocols "$protocol"); do
        port_forward_delete_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_apply_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      done
      save_iptables
      target_vps=$(get_vps_name_by_ip "$internal_ip" 2>/dev/null || true)
      [ -n "$target_vps" ] && sync_vps_port_forwards_metadata "$target_vps"
      echo "Port forward updated: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;

    delete)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward delete <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}" external_port="${4:-}" internal_ip="${5:-}" internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }

      local proto target_vps
      for proto in $(resolve_protocols "$protocol"); do
        port_forward_delete_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      done
      save_iptables
      target_vps=$(get_vps_name_by_ip "$internal_ip" 2>/dev/null || true)
      [ -n "$target_vps" ] && sync_vps_port_forwards_metadata "$target_vps"
      echo "Port forward removed: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;

    save)       port_forward_save_rules_to_file "${2:-$target_file}";;
    export)     port_forward_save_rules_to_file "${2:-$target_file}"; echo "Exported rules to ${2:-$target_file}";;
    load|import) port_forward_load_rules_from_file "${2:-$target_file}";;
    delete-all) port_forward_delete_all_rules "${2:-$target_file}";;
    disable)    port_forward_disable_rules "${2:-$target_file}";;
    enable)     port_forward_enable_rules "${2:-$target_file}";;
    status)     port_forward_status;;
    list)       port_forward_list_rules;;
    *)
      echo "Usage: vpsforge port-forward add|edit|delete|save|load|export|import|delete-all|enable|disable|list|status [args]"
      return 1
      ;;
  esac
}
