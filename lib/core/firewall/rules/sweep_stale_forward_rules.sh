#!/bin/bash
# Self-healing: remove FORWARD and DNAT (port-forward) rules for addresses of the VPS network
# that no VPS owns any more (left by an older version, a crash or a manual delete), so a reused
# port or IP can never route to the wrong VPS. Silent when there is nothing to remove.
sweep_stale_forward_rules() {
  local ip name removed=0
  local -A owned=()
  [ -n "${NETWORK_PREFIX:-}" ] || return 0

  # If Incus does not answer we cannot know who owns what: change nothing.
  incus list -c n --format csv >/dev/null 2>&1 || return 0

  local port inventory
  # A VPS whose address is not known yet (still being created) must not look "unowned": stop then.
  inventory=$(vps_inventory) || return 0
  while IFS='|' read -r name ip port; do
    [ -n "$name" ] || continue
    [ -n "$ip" ] || return 0
    owned["$ip"]=1
  done <<< "$inventory"

  while read -r ip; do
    [ -n "$ip" ] || continue
    [ "$ip" = "${INCUS_GATEWAY:-}" ] && continue
    [ -n "${owned[$ip]:-}" ] && continue
    remove_vps_forward_rules "$ip"
    removed=$((removed + 1))
  done < <(iptables -S FORWARD 2>/dev/null | grep -oE -- "-[ds] ${NETWORK_PREFIX//./\\.}\.[0-9]+/32" | awk '{print $2}' | sed 's#/32##' | sort -u)

  # Also sweep DNAT (port-forward) rules in PREROUTING that point to a VPS address no one owns,
  # or the old delete left behind: otherwise a reused port keeps routing to a dead/other VPS.
  local spec dip
  while read -r spec; do
    [ -n "$spec" ] || continue
    dip=$(printf '%s\n' "$spec" | grep -oE -- "--to-destination ${NETWORK_PREFIX//./\\.}\.[0-9]+" | awk '{print $2}')
    [ -n "$dip" ] || continue
    [ "$dip" = "${INCUS_GATEWAY:-}" ] && continue
    [ -n "${owned[$dip]:-}" ] && continue
    # shellcheck disable=SC2086
    iptables -t nat -D PREROUTING ${spec#-A PREROUTING } 2>/dev/null && removed=$((removed + 1))
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -- '-j DNAT' | grep -- "--to-destination ${NETWORK_PREFIX//./\\.}\.")

  [ "$removed" -gt 0 ] && save_iptables 2>/dev/null
  return 0
}
