#!/bin/bash
# Reinstall a VPS (optionally with another OS) keeping its IP, port, limits and login.
# SAFE: the original is kept aside (stopped, renamed <name>-old-reinstall) until the new
# one is completely ready. If anything fails or is interrupted, the new half-made VPS is
# deleted and the original is put back exactly as it was, with the reason shown.
#   reinstall_single_vps_core <name> [image]
reinstall_single_vps_core() {
  local name="$1" image="${2:-}" num ip port old="${1}-old-reinstall"
  num=$(get_num "$name")
  ip=$(get_ip "$name")
  port=$(get_vps_saved_port "$name" 2>/dev/null || true)
  [[ "$port" =~ ^[0-9]+$ ]] || port=$(vps_fixed_port "$num")

  preserve_vps_settings "$name"

  # If no image was given, reuse the one this VPS was made from (or the default).
  if [ -z "$image" ]; then
    image=$(incus config get "$name" user.vpsforge.image 2>/dev/null || true)
  fi
  [ -n "$image" ] || image="$VPS_IMAGE"

  print_preserved_settings "$name" "$port"

  _set_aside_vps_for_reinstall "$name" "$old" || return 1
  remove_ip "$ip"
  remove_port "$port"

  export VPS_FORCE_IP="$ip" VPS_FORCE_PORT="$port"   # the new VPS gets exactly the old address and port
  export VPS_KEEP_FORWARDS=1          # the owner's custom port-forwards must survive a failed reinstall
  if create_vps "$name" "$num" "$PRESERVED_RAM_LIMIT" "$port" \
      "$PRESERVED_RAM_MODE" "$PRESERVED_CPU_MODE" "$PRESERVED_CPU_LIMIT" \
      "$PRESERVED_DISK_MODE" "$PRESERVED_DISK_LIMIT" \
      "$PRESERVED_NETWORK_MODE" "$PRESERVED_NETWORK_LIMIT" \
      "$image" "$PRESERVED_TRAFFIC_MODE" "$PRESERVED_TRAFFIC_RX" "$PRESERVED_TRAFFIC_TX" "$PRESERVED_OPEN_SSH"; then
    unset VPS_KEEP_FORWARDS VPS_FORCE_IP VPS_FORCE_PORT
    _apply_reinstall_post_config "$name" "$old" "$image"
    return 0
  fi

  unset VPS_KEEP_FORWARDS VPS_FORCE_IP VPS_FORCE_PORT
  # create_vps already removed the half-made new VPS. Put the original back.
  echo "Reinstall of $name failed (${GUARD_REASON:-unknown reason}). Restoring the original VPS..."
  recover_interrupted_reinstall "$old" "$name"
  echo "FAILED reinstalling $name: the original VPS was restored unchanged."
  return 1
}
