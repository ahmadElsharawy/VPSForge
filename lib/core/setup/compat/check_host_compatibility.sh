#!/bin/bash
# Checks HOST-level capabilities that VPSForge cannot enable from inside a
# container. Reports the exact gap so the operator can fix it on the host.
check_host_compatibility() {
  local issues=0

  echo "Checking host compatibility for Docker/containerd/WireGuard/etc. workloads..."

  _check_kernel_modules_compatibility

  if [ -e /sys/fs/cgroup/cgroup.controllers ]; then
    :
  else
    echo "  [MISSING] Host is not using unified cgroup v2. Docker/containerd inside guests expect cgroup v2."
    echo "            Fix on host: enable cgroup v2 (systemd.unified_cgroup_hierarchy=1 kernel parameter) and reboot."
    issues=$((issues+1))
  fi

  if [ ! -e /dev/fuse ]; then
    modprobe fuse >/dev/null 2>&1 || true
    if [ ! -e /dev/fuse ]; then
      echo "  [MISSING] /dev/fuse is not present on the host. FUSE-based storage/tools inside guests may fail."
      echo "            Fix on host: modprobe fuse"
      issues=$((issues+1))
    fi
  fi

  if [ -e /sys/module/apparmor/parameters/enabled ] && [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = "Y" ]; then
    if ! command -v aa-status >/dev/null 2>&1 && [ ! -d /sys/kernel/security/apparmor ]; then
      echo "  [WARNING] AppArmor appears enabled but its securityfs interface is unavailable."
      echo "            VPSForge sets containers to lxc.apparmor.profile=unconfined; verify AppArmor tooling on host if issues occur."
    fi
  fi

  if [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)" != "1" ]; then
    echo "  [MISSING] net.ipv4.ip_forward is not enabled on the host."
    echo "            Fix on host: sysctl -w net.ipv4.ip_forward=1"
    issues=$((issues+1))
  fi

  # Docker's overlay2 storage driver host-level requirements.
  _check_storage_compatibility

  if [ "$issues" -eq 0 ]; then
    echo "Host compatibility check passed. All prerequisites for Docker/containerd/WireGuard/etc. are in place."
  else
    echo "Host compatibility check found $issues issue(s) above. VPSForge will not attempt workarounds for host-level gaps;"
    echo "please apply the fixes shown above on the HOST, then re-run VPSForge."
  fi
}
