#!/bin/bash
# VPSForge v1.0.0 — VPS reinstall core shared logic.

reinstall_single_vps_core() {
  local n="$1" image="${2:-}" num ip port
  num=$(get_num "$n")
  ip=$(get_ip "$n")
  port=$(vps_fixed_port "$num")

  preserve_vps_settings "$n"
  
  # If image parameter is empty, try to use the image that was configured on the VPS (or fallback to $VPS_IMAGE)
  if [ -z "$image" ]; then
    image=$(incus config get "$n" user.vpsforge.image 2>/dev/null || true)
  fi
  [ -n "$image" ] || image="$VPS_IMAGE"

  print_preserved_settings "$n" "$port"

  remove_ip "$ip"
  remove_port "$port"
  incus delete "$n" --force || { echo "FAILED deleting $n"; return 1; }

  if create_vps "$n" "$num" "$PRESERVED_RAM_LIMIT" "$port" \
      "$PRESERVED_RAM_MODE" "$PRESERVED_CPU_MODE" "$PRESERVED_CPU_LIMIT" \
      "$PRESERVED_DISK_MODE" "$PRESERVED_DISK_LIMIT" \
      "$PRESERVED_NETWORK_MODE" "$PRESERVED_NETWORK_LIMIT" \
      "$image"; then
    [ "$PRESERVED_USER" = "root" ] || change_vps_username "$n" "$PRESERVED_USER"
    change_vps_password "$n" "$PRESERVED_PASSWORD"
    echo "Reinstall completed for $n with image $image."
    return 0
  else
    echo "FAILED reinstalling $n"
    return 1
  fi
}
