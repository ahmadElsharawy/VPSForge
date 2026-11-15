#!/bin/bash
# Deletes network rules, snapshots, swapfile locks, and container instance for a single VPS.
_delete_single_vps() {
  local n="$1"
  local ip p del_retry del_err existed=0
  incus info "$n" >/dev/null 2>&1 && existed=1

  echo "Deleting $n..."
  ip=$(get_ip "$n")
  p=$(get_port "$ip")
  remove_ip "$ip"
  [ -n "$p" ] && remove_port "$p"
  remove_vps_forward_rules "$ip"
  [ -n "$ip" ] && port_forward_delete_rules_for_ip "$ip"
  rm -f "/etc/caddy/vpsforge/${n}.caddy"
  # Remove the VPN too (while the VPS still exists): its subscription web server, tokens, the three
  # port forwards and their firewall rules. Without this, deleting a VPS that had a VPN left a stray
  # sub-server process, its token directory and open forwards behind - a broken clean-host promise,
  # and a hazard if a new VPS later reused the same IP or VPN port.
  vpn_remove "$n" >/dev/null 2>&1 || true

  _delete_vps_snapshots "$n"
  _delete_clear_container_swap "$n"

  incus stop "$n" --force >/dev/null 2>&1 || true

  del_err=""
  for del_retry in 1 2 3; do
    del_err=$(incus delete "$n" --force 2>&1 || true)
    if ! incus list -c n --format csv 2>/dev/null | grep -Fxq "$n"; then
      break
    fi
    # Retry clearing swapfile attribute on failure
    _delete_clear_container_swap "$n"
    sleep 1
  done
  if incus list -c n --format csv 2>/dev/null | grep -Fxq "$n"; then
    echo "WARNING: $n still appears in Incus. Details: ${del_err:-Unknown error}"
  elif [ "$existed" = 1 ]; then
    echo "Deleted $n"
    delete_vps_backups_prompt "$n"
  else
    echo "No VPS named '$n' was found (cleaned up any leftover rules just in case)."
  fi
}
