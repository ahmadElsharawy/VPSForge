#!/bin/bash
# VPSForge v1.0.0 — Protocol helpers for port forwarding.

resolve_protocols() {
  case "$1" in
    both) echo "tcp udp";;
    *)    echo "$1";;
  esac
}

_build_dest_spec() {
  local ext_ip="${1:-}"
  if [ -n "$ext_ip" ] && [ "$ext_ip" != "0.0.0.0" ] && [ "$ext_ip" != "any" ]; then
    echo "-d $ext_ip"
  else
    echo "! -i incusbr0"
  fi
}
