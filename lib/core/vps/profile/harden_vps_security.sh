#!/bin/bash
# Lock a VPS down so one tenant cannot attack the host or its neighbours. Two protections:
#  1) L2/L3 anti-spoofing on the network card (mac/ipv4/ipv6 filtering), so a tenant cannot forge
#     ARP/NDP or send from an IP/MAC that is not its own -> no ARP poisoning or MITM of a neighbour.
#  2) A process-count cap (limits.processes), so a fork bomb inside one VPS cannot exhaust the host's
#     PID space and take the whole server (and every other tenant) down.
# Safe to call repeatedly; every step is idempotent and never fails the caller.
#   harden_vps_security <name>
harden_vps_security() {
  local name="$1"
  local max="${VPSFORGE_MAX_PROCESSES:-4096}"
  [ -n "$name" ] || return 0
  # Cap processes to stop fork bombs from starving the host of PIDs.
  incus config set "$name" limits.processes "$max" >/dev/null 2>&1 || true
  # Anti-spoofing on eth0. ipv4_filtering needs the card to have a known address; VPSForge gives every
  # VPS a fixed IP, so this holds. Docker inside the VPS still works: it SNATs to the VPS's own eth0 IP,
  # which the filter allows. Each is best-effort so a quirky host never blocks VPS creation.
  if incus config device get "$name" eth0 type >/dev/null 2>&1; then
    incus config device set "$name" eth0 security.mac_filtering true >/dev/null 2>&1 || true
    incus config device set "$name" eth0 security.ipv4_filtering true >/dev/null 2>&1 || true
    incus config device set "$name" eth0 security.ipv6_filtering true >/dev/null 2>&1 || true
  fi
  return 0
}
