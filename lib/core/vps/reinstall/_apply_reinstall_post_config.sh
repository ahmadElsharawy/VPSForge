#!/bin/bash
# Restore preserved user credentials and tunnel settings after a successful reinstall.
_apply_reinstall_post_config() {
  local name="$1" old="$2" image="$3"
  [ "$PRESERVED_USER" = "root" ] || change_vps_username "$name" "$PRESERVED_USER"
  change_vps_password "$name" "$PRESERVED_PASSWORD"
  [ -n "$PRESERVED_TRAFFIC_ACTION" ] && incus config set "$name" "user.vpsforge.traffic.action=$PRESERVED_TRAFFIC_ACTION" >/dev/null 2>&1
  if [ -n "$PRESERVED_TUNNELS" ]; then
    incus config set "$name" user.vpsforge.tunnels "$PRESERVED_TUNNELS"
    enable_vps_tunnel_access "$name" || echo "NOTE: could not re-enable tunnels inside $name; start them again from menu 12 > 4."
    echo "NOTE: the tunnel logins were reset by the reinstall. On each computer run menu 12 > 4 > Show the command > 1 again."
  fi
  incus delete "$old" --force >/dev/null 2>&1 || true
  reclaim_pool_space
  echo "Reinstall completed for $name with image $image."
}
