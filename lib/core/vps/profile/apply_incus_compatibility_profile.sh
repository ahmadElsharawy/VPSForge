#!/bin/bash
# VPSForge v1.0.0 — Incus compatibility profile.

apply_incus_compatibility_profile() {
  local name="$1" raw_lxc modules

  incus config set "$name" security.nesting true >/dev/null 2>&1 || true
  incus config set "$name" security.privileged true >/dev/null 2>&1 || true
  incus config set "$name" security.syscalls.intercept.mknod true >/dev/null 2>&1 || true
  incus config set "$name" security.syscalls.intercept.setxattr true >/dev/null 2>&1 || true
  # Only modules this kernel really has: an unknown one would make the VPS refuse to start.
  modules=$(get_loadable_kernel_modules overlay br_netfilter nf_nat ip_tables iptable_nat iptable_filter bridge veth fuse tun)
  if [ -n "$modules" ]; then
    incus config set "$name" linux.kernel_modules "$modules" >/dev/null 2>&1 || true
  else
    incus config unset "$name" linux.kernel_modules >/dev/null 2>&1 || true
  fi

  raw_lxc=$(cat <<'EOF'
lxc.apparmor.profile=unconfined
lxc.cap.drop=
EOF
)
  if ! incus config set "$name" raw.lxc "$raw_lxc" >/dev/null 2>&1; then
    echo "WARNING: Incus rejected the optional raw.lxc compatibility settings for $name; continuing without them." >&2
  fi

  return 0
}
