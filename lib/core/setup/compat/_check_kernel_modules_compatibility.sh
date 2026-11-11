#!/bin/bash
# Validates host kernel modules (overlay, br_netfilter) required for Docker and bridged traffic.
_check_kernel_modules_compatibility() {
  if ! ( grep -qw overlay /proc/filesystems 2>/dev/null || [ -d /sys/module/overlay ] || lsmod 2>/dev/null | grep -q '^overlay' ); then
    modprobe overlay >/dev/null 2>&1 || true
    if ! ( grep -qw overlay /proc/filesystems 2>/dev/null || [ -d /sys/module/overlay ] || lsmod 2>/dev/null | grep -q '^overlay' ); then
      echo "  [MISSING] Kernel module 'overlay' is not loaded. Docker's overlay2 storage driver inside guests may fail."
      echo "            Fix on host: modprobe overlay"
      issues=$((issues+1))
    fi
  fi

  if ! ( [ -d /sys/module/br_netfilter ] || [ -e /proc/sys/net/bridge/bridge-nf-call-iptables ] || lsmod 2>/dev/null | grep -q '^br_netfilter' ); then
    modprobe br_netfilter >/dev/null 2>&1 || true
    if ! ( [ -d /sys/module/br_netfilter ] || [ -e /proc/sys/net/bridge/bridge-nf-call-iptables ] || lsmod 2>/dev/null | grep -q '^br_netfilter' ); then
      echo "  [MISSING] Kernel module 'br_netfilter' is not loaded. iptables/nftables may not see bridged container traffic."
      echo "            Fix on host: modprobe br_netfilter"
      issues=$((issues+1))
    fi
  fi
}
