#!/bin/bash
# Configure and persist sysctls required for container nesting and bridged traffic.
_apply_host_nesting_sysctl() {
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
  } > /etc/sysctl.d/99-vpsforge-nesting.conf
  sysctl -p /etc/sysctl.d/99-vpsforge-nesting.conf >/dev/null 2>&1 || true
}
