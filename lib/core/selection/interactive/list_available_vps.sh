#!/bin/bash
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
