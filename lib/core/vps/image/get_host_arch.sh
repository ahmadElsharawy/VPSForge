#!/bin/bash
# Detect host architecture and map it to Incus architecture names (amd64, arm64, armhf).
get_host_arch() {
  local arch
  arch=$(uname -m 2>/dev/null || echo "x86_64")
  case "$arch" in
    x86_64|amd64)   echo "amd64" ;;
    aarch64|arm64)  echo "arm64" ;;
    armv7l|armhf)   echo "armhf" ;;
    *)              echo "$arch" ;;
  esac
}
