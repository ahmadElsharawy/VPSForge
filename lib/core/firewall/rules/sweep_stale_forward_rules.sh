#!/bin/bash
# Self-healing: remove FORWARD rules for addresses of the VPS network that no VPS owns any more
# (left by an older version, a crash or a manual delete). Silent when there is nothing to remove.
sweep_stale_forward_rules() {
  local ip name removed=0
  local -A owned=()
  [ -n "${NETWORK_PREFIX:-}" ] || return 0

  # If Incus does not answer we cannot know who owns what: change nothing.
  incus list -c n --format csv >/dev/null 2>&1 || return 0

  while read -r name; do
    [ -n "$name" ] || continue
    ip=$(incus config get "$name" user.vpsforge.ip 2>/dev/null || true)
    [ -n "$ip" ] && owned["$ip"]=1
    ip=$(get_ip "$name" 2>/dev/null || true)
    [ -n "$ip" ] && owned["$ip"]=1
  done < <(incus list -c n --format csv 2>/dev/null)

  while read -r ip; do
    [ -n "$ip" ] || continue
    [ "$ip" = "${INCUS_GATEWAY:-}" ] && continue
    [ -n "${owned[$ip]:-}" ] && continue
    remove_vps_forward_rules "$ip"
    removed=$((removed + 1))
  done < <(iptables -S FORWARD 2>/dev/null | grep -oE -- "-[ds] ${NETWORK_PREFIX//./\\.}\.[0-9]+/32" | awk '{print $2}' | sed 's#/32##' | sort -u)

  [ "$removed" -gt 0 ] && save_iptables 2>/dev/null
  return 0
}
