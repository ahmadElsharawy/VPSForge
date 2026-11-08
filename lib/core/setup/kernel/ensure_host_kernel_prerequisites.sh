#!/bin/bash
# VPSForge v1.0.0 — Host kernel prerequisites for nested containers.

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
