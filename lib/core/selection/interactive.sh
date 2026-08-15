#!/bin/bash
# VPSForge v1.0.0 — Interactive VPS selection UI.

# ── Global Selection State ───────────────────────────────────────────────────
SELECTED_VPS=()
SELECTED=""
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

# ── Interactive Selection ────────────────────────────────────────────────────

ask_vps_selection() {
  local prompt_text="${1:-Select VPS by number, name, or A for All [0=Back, Enter=1]: }" raw
  list_available_vps || return 1
  read -r -p "$prompt_text" raw </dev/tty
  raw="${raw:-1}"
  if [ "$raw" = "0" ]; then
    echo "Cancelled."
    return 1
  fi
  normalize_selection "$raw"
}

# For Details and Connection menus: pressing Enter selects all.
ask_vps_selection_enter_all() {
  local input
  list_available_vps || return 1
  read -r -p "Select VPS by number, name, or A for All [0=Back, Enter=All]: " input </dev/tty
  input="${input:-All}"
  if [ "$input" = "0" ]; then
    echo "Cancelled."
    return 1
  fi
  normalize_selection "$input" || return 1
  [ "${#SELECTED_VPS[@]}" -gt 0 ] || { echo "No VPS containers selected."; return 1; }
}

show_selection() {
  echo "Selected: ${SELECTED_VPS[*]}"
}

# Single-VPS selection (for shell access, etc.).
select_vps() {
  list_available_vps || return 1
  read -r -p "Select VPS by number or name [0=Back, Enter=1]: " SELECTED </dev/tty
  SELECTED="${SELECTED:-1}"
  if [ "$SELECTED" = "0" ]; then
    echo "Cancelled."
    return 1
  fi
  if [[ "$SELECTED" =~ ^[0-9]+$ ]] && [ "$SELECTED" -ge 1 ] && [ "$SELECTED" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
    local idx=$((SELECTED - 1))
    SELECTED="${AVAILABLE_VPS_LIST[$idx]}"
  elif [[ "$SELECTED" =~ ^[0-9]+$ ]]; then
    SELECTED="${VPS_PREFIX}${SELECTED}"
  fi
  incus info "$SELECTED" >/dev/null 2>&1 || { echo "Not found: $SELECTED"; return 1; }
}
