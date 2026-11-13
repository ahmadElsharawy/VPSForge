#!/bin/bash
# Make a VPS Isolated and ready for Docker. Unprivileged with the Incus AppArmor profile kept, so
# root inside the VPS is an ordinary user on the server (safe to rent to strangers). Nesting and
# /dev/fuse are on so Docker runs inside it (with crun + fuse-overlayfs, see _prepare_guest_docker),
# and the kernel modules Docker's networking needs are loaded on the host.
apply_incus_compatibility_profile() {
  local name="$1" modules
  # Only modules this kernel really has: an unknown one would make the VPS refuse to start.
  modules=$(get_loadable_kernel_modules overlay br_netfilter nf_nat ip_tables iptable_nat iptable_filter bridge veth fuse tun)
  if [ -n "$modules" ]; then
    incus config set "$name" linux.kernel_modules "$modules" >/dev/null 2>&1 || true
  else
    incus config unset "$name" linux.kernel_modules >/dev/null 2>&1 || true
  fi
  incus config set "$name" security.privileged false >/dev/null 2>&1 || true
  incus config set "$name" security.nesting true >/dev/null 2>&1 || true
  incus config set "$name" security.syscalls.intercept.mknod true >/dev/null 2>&1 || true
  incus config set "$name" security.syscalls.intercept.setxattr true >/dev/null 2>&1 || true
  incus config unset "$name" raw.lxc >/dev/null 2>&1 || true
  # fuse-overlayfs (Docker's storage inside an unprivileged VPS) needs /dev/fuse.
  if [ -e /dev/fuse ] && ! incus config device get "$name" fuse type >/dev/null 2>&1; then
    incus config device add "$name" fuse unix-char source=/dev/fuse path=/dev/fuse >/dev/null 2>&1 || true
  fi
  return 0
}
