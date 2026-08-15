#!/bin/bash

delete_vps_menu() {
  local n ip p
  ask_vps_selection || return 1
  show_selection
  read -r -p "Type DELETE to permanently delete, or 0 to cancel: " x
  [ "$x" = "0" ] && { echo "Cancelled."; return 1; }
  [ "$x" = "DELETE" ] || { echo "Cancelled."; return 1; }

  for n in "${SELECTED_VPS[@]}"; do
    echo "Deleting $n..."
    ip=$(get_ip "$n"); p=$(get_port "$ip")
    remove_ip "$ip"; [ -n "$p" ] && remove_port "$p"
    [ -n "$ip" ] && port_forward_delete_rules_for_ip "$ip"
    rm -f "/etc/caddy/vpsforge/${n}.caddy"
    
    # Delete container snapshots first if any exist
    local s_list
    mapfile -t s_list < <(incus snapshot list "$n" --format csv 2>/dev/null | cut -d',' -f1 || true)
    for snap in "${s_list[@]}"; do
      [ -n "$snap" ] && incus snapshot delete "$n" "$snap" >/dev/null 2>&1 || true
    done

    # Disable swap and remove immutable flags inside container & on host storage rootfs
    incus exec "$n" -- sh -c "swapoff -a 2>/dev/null || true"
    incus exec "$n" -- sh -c "chattr -i -a /swapfile 2>/dev/null || true"

    incus stop "$n" --force >/dev/null 2>&1 || true

    # Clear host-side swapfile locks / immutable attributes if present in storage pools
    local sf
    for sf in /var/lib/incus/storage-pools/*/containers/"$n"/rootfs/swapfile /var/lib/lxd/storage-pools/*/containers/"$n"/rootfs/swapfile; do
      if [ -f "$sf" ]; then
        swapoff "$sf" 2>/dev/null || true
        chattr -i -a "$sf" 2>/dev/null || true
        rm -f "$sf" 2>/dev/null || true
      fi
    done

    local del_retry=0 del_err=""
    for del_retry in 1 2 3; do
      del_err=$(incus delete "$n" --force 2>&1 || true)
      if ! incus list -c n --format csv 2>/dev/null | grep -Fxq "$n"; then
        break
      fi
      # Retry clearing swapfile attribute on failure
      for sf in /var/lib/incus/storage-pools/*/containers/"$n"/rootfs/swapfile; do
        swapoff "$sf" 2>/dev/null || true
        chattr -i -a "$sf" 2>/dev/null || true
        rm -f "$sf" 2>/dev/null || true
      done
      sleep 1
    done
    if incus list -c n --format csv 2>/dev/null | grep -Fxq "$n"; then
      echo "WARNING: $n still appears in Incus. Details: ${del_err:-Unknown error}"
    else
      echo "Deleted $n"
    fi
  done
  systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  save_iptables
  pause
  return 0
}
