#!/bin/bash
# Displays CPU, RAM, disk, and network usage and limits for a VPS.
_details_print_resources() {
  local name="$1"
  local ram ram_limit cpu cpu_limit disk disk_limit network network_limit net_io

  ram=$(format_ram_display "$name" 2>/dev/null || true); [ -n "$ram" ] || ram="-"
  ram_limit=$(get_vps_ram_limit_mb "$name" 2>/dev/null || true)
  cpu=$(_details_format_cpu_display "$name")
  cpu_limit=$(incus config get "$name" limits.cpu 2>/dev/null || true)

  disk=$(format_disk_display "$name" 2>/dev/null || true); [ -n "$disk" ] || disk="-"
  disk_limit=$(get_vps_disk_limit_gb "$name" 2>/dev/null || true)

  network=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
  if [ -n "$network" ]; then
    network="${network}Mbit"
  else
    network=$(get_total_network_mbit 2>/dev/null || true)
    [ -n "$network" ] && network="${network}Mbit" || network="-"
  fi
  network_limit=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
  net_io=$(get_vps_network_io_display "$name" 2>/dev/null || echo "-")

  echo "── Resources & Usage ───────────────────────────────────────────"
  echo "  RAM Usage:      $ram ($([ -n "$ram_limit" ] && echo "Limited: ${ram_limit}MB" || echo "Unlimited"))"
  echo "  CPU Cores:      $cpu ($([ -n "$cpu_limit" ] && echo "Limited: ${cpu_limit} core(s)" || echo "Unlimited"))"
  echo "  Disk Usage:     $disk ($([ -n "$disk_limit" ] && echo "Limited: ${disk_limit}GB" || echo "Unlimited"))"
  echo "  Network Limit:  $network ($([ -n "$network_limit" ] && echo "Limited: ${network_limit}Mbit" || echo "Unlimited"))"
  echo "  Network I/O:    $net_io"
  echo
}
