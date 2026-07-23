#!/bin/bash
# VPSForge — Host compatibility checks and initial setup.

# ── Initial Setup ────────────────────────────────────────────────────────────

ensure_setup() {
  command -v incus >/dev/null 2>&1 || { apt-get update && apt-get install -y incus; }
  command -v iptables >/dev/null 2>&1 || apt-get install -y iptables
  command -v netfilter-persistent >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
  command -v curl >/dev/null 2>&1 || apt-get install -y curl
  incus network show incusbr0 >/dev/null 2>&1 || incus admin init --minimal

  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-incus-forwarding.conf

  setup_inter_vps_isolation

  # Host-side kernel modules and sysctls required for Docker/containerd/WireGuard/etc.
  # to work correctly inside nested Incus/LXC system containers.
  ensure_host_kernel_prerequisites
  check_host_compatibility
}

# ── Kernel Prerequisites ─────────────────────────────────────────────────────

# Loads and persists the kernel modules and sysctl values that the HOST needs
# so that nested workloads (Docker, containerd, WireGuard, nftables, bridging,
# etc.) work correctly inside VPSForge-created containers.
ensure_host_kernel_prerequisites() {
  local mod

  for mod in overlay br_netfilter ip_tables ip6_tables iptable_nat ip6table_nat \
             nf_nat nf_conntrack xt_conntrack bridge veth fuse tun; do
    modprobe "$mod" >/dev/null 2>&1 || true
  done

  # Persist module loading across reboots.
  cat > /etc/modules-load.d/vpsforge.conf <<'EOF'
overlay
br_netfilter
ip_tables
ip6_tables
iptable_nat
ip6table_nat
nf_nat
nf_conntrack
xt_conntrack
bridge
veth
fuse
tun
EOF

  # Sysctls required for bridged traffic to traverse iptables/nftables correctly.
  {
    echo 'net.ipv4.ip_forward=1'
    if [ -e /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
      echo 'net.bridge.bridge-nf-call-iptables=1'
    fi
    if [ -e /proc/sys/net/bridge/bridge-nf-call-ip6tables ]; then
      echo 'net.bridge.bridge-nf-call-ip6tables=1'
    fi
    if [ -e /proc/sys/net/ipv4/conf/all/forwarding ]; then
      echo 'net.ipv4.conf.all.forwarding=1'
    fi
    if [ -e /proc/sys/net/ipv6/conf/all/forwarding ]; then
      echo 'net.ipv6.conf.all.forwarding=1'
    fi
  } > /etc/sysctl.d/99-vpsforge-nesting.conf
  sysctl -p /etc/sysctl.d/99-vpsforge-nesting.conf >/dev/null 2>&1 || true
}

# ── Compatibility Check ──────────────────────────────────────────────────────

# Checks HOST-level capabilities that VPSForge cannot enable from inside a
# container. Reports the exact gap so the operator can fix it on the host.
check_host_compatibility() {
  local issues=0

  echo "Checking host compatibility for Docker/containerd/WireGuard/etc. workloads..."

  if ! lsmod 2>/dev/null | grep -q '^overlay'; then
    echo "  [MISSING] Kernel module 'overlay' is not loaded. Docker's overlay2 storage driver inside guests may fail."
    echo "            Fix on host: modprobe overlay"
    issues=$((issues+1))
  fi

  if ! lsmod 2>/dev/null | grep -q '^br_netfilter'; then
    echo "  [MISSING] Kernel module 'br_netfilter' is not loaded. iptables/nftables may not see bridged container traffic."
    echo "            Fix on host: modprobe br_netfilter"
    issues=$((issues+1))
  fi

  if [ -e /sys/fs/cgroup/cgroup.controllers ]; then
    :
  else
    echo "  [MISSING] Host is not using unified cgroup v2. Docker/containerd inside guests expect cgroup v2."
    echo "            Fix on host: enable cgroup v2 (systemd.unified_cgroup_hierarchy=1 kernel parameter) and reboot."
    issues=$((issues+1))
  fi

  if [ ! -e /dev/fuse ]; then
    echo "  [MISSING] /dev/fuse is not present on the host. FUSE-based storage/tools inside guests may fail."
    echo "            Fix on host: modprobe fuse"
    issues=$((issues+1))
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

# ── Private: Storage Compatibility ───────────────────────────────────────────

_check_storage_compatibility() {
  local pool pool_source fstype

  pool=$(incus profile device get default root pool 2>/dev/null || true)
  [ -n "$pool" ] || pool="default"
  pool_source=$(incus storage show "$pool" 2>/dev/null | awk -F': ' '/^[[:space:]]*source:/{print $2; exit}')
  [ -n "$pool_source" ] && [ -e "$pool_source" ] || pool_source="/var/lib/incus/storage-pools/${pool}"

  [ -e "$pool_source" ] || return 0

  fstype=$(stat -f -c %T "$pool_source" 2>/dev/null || echo "unknown")

  if [[ "$fstype" == *overlay* ]]; then
    echo "  [MISSING] The Incus storage pool '$pool' ($pool_source) sits on an OVERLAYFS backing filesystem."
    echo "            Docker's overlay2 driver does not support running overlay-on-overlay (official Docker limitation)."
    echo "            Fix on host: provision the Incus storage pool on ext4, xfs (ftype=1), btrfs, or zfs instead."
    issues=$((issues+1))
  elif [[ "$fstype" == *xfs* ]]; then
    if command -v xfs_info >/dev/null 2>&1; then
      local ftype
      ftype=$(xfs_info "$pool_source" 2>/dev/null | grep -oE 'ftype=[01]' | cut -d= -f2)
      if [ "$ftype" = "0" ]; then
        echo "  [MISSING] The Incus storage pool '$pool' ($pool_source) is on XFS with ftype=0 (d_type disabled)."
        echo "            Docker's overlay2 driver refuses to run without d_type support."
        echo "            Fix on host: reformat with 'mkfs.xfs -n ftype=1' and recreate the storage pool."
        issues=$((issues+1))
      fi
    else
      echo "  [WARNING] Storage pool '$pool' is on XFS but 'xfs_info' is not installed, so ftype=1 support could not be verified."
      echo "            Install xfsprogs on the host and run: xfs_info $pool_source"
    fi
  fi
}
