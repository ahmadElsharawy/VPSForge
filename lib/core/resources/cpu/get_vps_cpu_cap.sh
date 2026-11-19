#!/bin/bash
# Prints the CPU cap percent of a VPS (empty when it has no cap).
get_vps_cpu_cap() {
  incus config get "$1" user.vpsforge.cpu_cap 2>/dev/null || true
}
