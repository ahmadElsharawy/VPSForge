#!/bin/bash
# Reinstall a VPS (optionally with another OS) keeping its IP, port, limits and login.
# SAFE: the original is kept aside (stopped, renamed <name>-old-reinstall) until the new
# one is completely ready. If anything fails or is interrupted, the new half-made VPS is
# deleted and the original is put back exactly as it was, with the reason shown.
#   reinstall_single_vps_core <name> [image]
reinstall_single_vps_core() {
  local n="$1" image="${2:-}" num ip port old="${1}-old-reinstall"
  num=$(get_num "$n")
  ip=$(get_ip "$n")
  port=$(get_vps_saved_port "$n" 2>/dev/null || true)
  [[ "$port" =~ ^[0-9]+$ ]] || port=$(vps_fixed_port "$num")

  preserve_vps_settings "$n"

  # If no image was given, reuse the one this VPS was made from (or the default).
  if [ -z "$image" ]; then
    image=$(incus config get "$n" user.vpsforge.image 2>/dev/null || true)
  fi
  [ -n "$image" ] || image="$VPS_IMAGE"

  print_preserved_settings "$n" "$port"

  # Keep the original aside instead of deleting it.
  incus delete "$old" --force >/dev/null 2>&1 || true
  incus stop "$n" --force >/dev/null 2>&1 || true
  if ! incus rename "$n" "$old"; then
    echo "ERROR: could not set the original VPS aside; nothing was changed."
    return 1
  fi
  mark_vps_state "$old" reinstall-old
  incus config set "$old" user.vpsforge.reinstall_of "$n" >/dev/null 2>&1 || true
  remove_ip "$ip"
  remove_port "$port"

  export VPS_FORCE_IP="$ip" VPS_FORCE_PORT="$port"   # the new VPS gets exactly the old address and port
  export VPS_KEEP_FORWARDS=1          # the owner's custom port-forwards must survive a failed reinstall
  if create_vps "$n" "$num" "$PRESERVED_RAM_LIMIT" "$port" \
      "$PRESERVED_RAM_MODE" "$PRESERVED_CPU_MODE" "$PRESERVED_CPU_LIMIT" \
      "$PRESERVED_DISK_MODE" "$PRESERVED_DISK_LIMIT" \
      "$PRESERVED_NETWORK_MODE" "$PRESERVED_NETWORK_LIMIT" \
      "$image"; then
    unset VPS_KEEP_FORWARDS VPS_FORCE_IP VPS_FORCE_PORT
    [ "$PRESERVED_USER" = "root" ] || change_vps_username "$n" "$PRESERVED_USER"
    change_vps_password "$n" "$PRESERVED_PASSWORD"
    if [ -n "$PRESERVED_TUNNELS" ]; then
      incus config set "$n" user.vpsforge.tunnels "$PRESERVED_TUNNELS"
      enable_vps_tunnel_access "$n" || echo "NOTE: could not re-enable tunnels inside $n; start them again from menu 12 > 4."
    fi
    incus delete "$old" --force >/dev/null 2>&1 || true
    reclaim_pool_space
    echo "Reinstall completed for $n with image $image."
    return 0
  fi

  unset VPS_KEEP_FORWARDS VPS_FORCE_IP VPS_FORCE_PORT
  # create_vps already removed the half-made new VPS. Put the original back.
  echo "Reinstall of $n failed (${GUARD_REASON:-unknown reason}). Restoring the original VPS..."
  recover_interrupted_reinstall "$old" "$n"
  echo "FAILED reinstalling $n: the original VPS was restored unchanged."
  return 1
}
