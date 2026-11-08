#!/bin/bash
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
