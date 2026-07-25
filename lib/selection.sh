#!/bin/bash
# VPSForge — VPS selection, normalization, and numbering.

# ── Global Selection State ───────────────────────────────────────────────────
# SELECTED_VPS=() is populated by ask_vps_selection / normalize_selection.
# SELECTED is populated by select_vps (single-VPS selection).

SELECTED_VPS=()
SELECTED=""

# ── Normalize Input ──────────────────────────────────────────────────────────

AVAILABLE_VPS_LIST=()

list_available_vps() {
  AVAILABLE_VPS_LIST=()
  mapfile -t AVAILABLE_VPS_LIST < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' | sort -V || true)

  if [ "${#AVAILABLE_VPS_LIST[@]}" -eq 0 ]; then
    echo "No VPS containers found on this server."
    return 1
  fi

  echo "Available VPS Containers:"
  local idx=1 n ip status
  for n in "${AVAILABLE_VPS_LIST[@]}"; do
    ip=$(get_ip "$n" 2>/dev/null || true); [ -n "$ip" ] || ip="No-IP"
    status=$(get_state "$n" 2>/dev/null || true); [ -n "$status" ] || status="-"
    printf "   %2d) %-15s (%-14s | %s)\n" "$idx" "$n" "$ip" "$status"
    idx=$((idx + 1))
  done
  echo "   A) All Containers"
  echo ""
  return 0
}

# Accepts "1,2", "1", "test2", "vps1", or "all"/"A" and populates SELECTED_VPS array.
normalize_selection() {
  local raw="$1" token name idx
  SELECTED_VPS=()

  if [[ "${raw,,}" == "a" ]] || [[ "${raw,,}" == "all" ]]; then
    mapfile -t SELECTED_VPS < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' | sort -V || true)
  else
    IFS=',' read -ra TOKENS <<< "$raw"
    for token in "${TOKENS[@]}"; do
      token="${token//[[:space:]]/}"
      [ -z "$token" ] && continue

      # Try token as a 1-based index from AVAILABLE_VPS_LIST
      if [[ "$token" =~ ^[0-9]+$ ]] && [ "$token" -ge 1 ] && [ "$token" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
        idx=$((token - 1))
        name="${AVAILABLE_VPS_LIST[$idx]}"
      else
        if [[ "$token" =~ ^[0-9]+$ ]]; then
          name="${VPS_PREFIX}${token}"
        else
          name="$token"
        fi
      fi

      if incus info "$name" >/dev/null 2>&1; then
        [[ " ${SELECTED_VPS[*]} " == *" $name "* ]] || SELECTED_VPS+=("$name")
      else
        echo "Not found: $token ($name)"
        return 1
      fi
    done
  fi

  [ "${#SELECTED_VPS[@]}" -gt 0 ] || { echo "No VPS selected."; return 1; }
}

# ── Interactive Selection ────────────────────────────────────────────────────

ask_vps_selection() {
  local prompt_text="${1:-Select VPS by number, name, or A for All: }" raw
  list_available_vps || return 1
  read -r -p "$prompt_text" raw </dev/tty
  normalize_selection "$raw"
}

# For Details and Connection menus: pressing Enter selects all.
ask_vps_selection_enter_all() {
  local input
  list_available_vps || return 1
  read -r -p "Select VPS by number, name, or A for All [Enter = All]: " input </dev/tty
  [ -n "$input" ] || input="All"
  normalize_selection "$input" || return 1
  [ "${#SELECTED_VPS[@]}" -gt 0 ] || { echo "No VPS containers selected."; return 1; }
}

show_selection() {
  echo "Selected: ${SELECTED_VPS[*]}"
}

# Single-VPS selection (for shell access, etc.).
select_vps() {
  list_available_vps || return 1
  read -r -p "Select VPS by number or name: " SELECTED </dev/tty
  if [[ "$SELECTED" =~ ^[0-9]+$ ]] && [ "$SELECTED" -ge 1 ] && [ "$SELECTED" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
    local idx=$((SELECTED - 1))
    SELECTED="${AVAILABLE_VPS_LIST[$idx]}"
  elif [[ "$SELECTED" =~ ^[0-9]+$ ]]; then
    SELECTED="${VPS_PREFIX}${SELECTED}"
  fi
  incus info "$SELECTED" >/dev/null 2>&1 || { echo "Not found: $SELECTED"; return 1; }
}

# ── Numbering ────────────────────────────────────────────────────────────────

# Returns the next available VPS number (highest existing + 1).
next_num() {
  local highest=0 name num saved_num ip last_octet
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    num=""
    saved_num=$(incus config get "$name" user.vpsforge.num 2>/dev/null || true)
    if [[ "$saved_num" =~ ^[0-9]+$ ]]; then
      num="$saved_num"
    elif [[ "$name" =~ ^${VPS_PREFIX}([0-9]+)$ ]]; then
      num="${BASH_REMATCH[1]}"
    else
      ip=$(incus config get "$name" user.vpsforge.ip 2>/dev/null || true)
      if [[ "$ip" =~ \.([0-9]+)$ ]]; then
        last_octet="${BASH_REMATCH[1]}"
        num=$((last_octet - IP_START + 1))
      fi
    fi
    if [[ "$num" =~ ^[0-9]+$ ]] && (( num > highest )); then
      highest="$num"
    fi
  done < <(incus list -c n --format csv 2>/dev/null || true)
  echo $((highest + 1))
}
