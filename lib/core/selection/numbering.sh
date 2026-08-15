#!/bin/bash
# VPSForge v1.0.0 — VPS numbering and identification.

# Extract or lookup numeric identifier for a VPS (e.g. vps3 → 3, or custom name → metadata/IP num)
get_num() {
  local name="$1" num ip last_octet
  num=$(incus config get "$name" user.vpsforge.num 2>/dev/null || true)
  if [[ "$num" =~ ^[0-9]+$ ]]; then
    echo "$num"
    return
  fi
  if [[ "$name" =~ ^${VPS_PREFIX}([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  ip=$(incus config get "$name" user.vpsforge.ip 2>/dev/null || true)
  if [[ "$ip" =~ \.([0-9]+)$ ]]; then
    last_octet="${BASH_REMATCH[1]}"
    echo $((last_octet - IP_START + 1))
    return
  fi
  echo "$name" | sed "s/^${VPS_PREFIX}//"
}

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
