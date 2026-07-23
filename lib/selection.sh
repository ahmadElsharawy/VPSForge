#!/bin/bash
# VPSForge — VPS selection, normalization, and numbering.

# ── Global Selection State ───────────────────────────────────────────────────
# SELECTED_VPS=() is populated by ask_vps_selection / normalize_selection.
# SELECTED is populated by select_vps (single-VPS selection).

SELECTED_VPS=()
SELECTED=""

# ── Normalize Input ──────────────────────────────────────────────────────────

# Accepts "1,3,vps6,10" or "all" and populates SELECTED_VPS array.
normalize_selection() {
  local raw="$1" token name
  SELECTED_VPS=()

  if [[ "${raw,,}" = "all" ]]; then
    mapfile -t SELECTED_VPS < <(incus list -c n --format csv | grep -E "^${VPS_PREFIX}[0-9]+$" | sort -V || true)
  else
    IFS=',' read -ra TOKENS <<< "$raw"
    for token in "${TOKENS[@]}"; do
      token="${token//[[:space:]]/}"
      [ -z "$token" ] && continue
      [[ "$token" =~ ^[0-9]+$ ]] && name="${VPS_PREFIX}${token}" || name="$token"
      [[ "$name" =~ ^${VPS_PREFIX}[0-9]+$ ]] || { echo "Invalid VPS: $token"; return 1; }
      incus info "$name" >/dev/null 2>&1 || { echo "Not found: $name"; return 1; }
      [[ " ${SELECTED_VPS[*]} " == *" $name "* ]] || SELECTED_VPS+=("$name")
    done
  fi

  [ "${#SELECTED_VPS[@]}" -gt 0 ] || { echo "No VPS selected."; return 1; }
}

# ── Interactive Selection ────────────────────────────────────────────────────

ask_vps_selection() {
  local prompt="${1:-VPS name/number, comma-separated list, or All: }" raw
  read -r -p "$prompt" raw
  normalize_selection "$raw"
}

# For Details and Connection menus: pressing Enter selects all.
ask_vps_selection_enter_all() {
  local input
  read -r -p "VPS name/number, comma-separated list, or All [Enter = All]: " input
  [ -n "$input" ] || input="All"
  normalize_selection "$input" || return 1
  [ "${#SELECTED_VPS[@]}" -gt 0 ] || { echo "No VPS containers selected."; return 1; }
}

show_selection() {
  echo "Selected: ${SELECTED_VPS[*]}"
}

# Single-VPS selection (for shell access, etc.).
select_vps() {
  read -r -p "VPS name or number: " SELECTED
  [[ "$SELECTED" =~ ^[0-9]+$ ]] && SELECTED="${VPS_PREFIX}${SELECTED}"
  incus info "$SELECTED" >/dev/null 2>&1 || { echo "Not found: $SELECTED"; return 1; }
}

# ── Numbering ────────────────────────────────────────────────────────────────

# Returns the next available VPS number (highest existing + 1).
next_num() {
  local highest=0 name num
  while IFS= read -r name; do
    [[ "$name" =~ ^${VPS_PREFIX}([0-9]+)$ ]] || continue
    num="${BASH_REMATCH[1]}"
    (( num > highest )) && highest="$num"
  done < <(incus list -c n --format csv 2>/dev/null || true)
  echo $((highest + 1))
}
