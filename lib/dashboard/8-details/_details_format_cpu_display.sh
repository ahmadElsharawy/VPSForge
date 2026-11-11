#!/bin/bash
# Formats the CPU allocation string showing allocated, remaining, and total host cores.
_details_format_cpu_display() {
  local name="$1"
  local host_cpus raw_cpu rem_cpu=0
  host_cpus=$(get_host_cpu_count 2>/dev/null || echo 1)
  raw_cpu=$(incus config get "$name" limits.cpu 2>/dev/null || true)
  if [ -n "$raw_cpu" ]; then
    [[ "$raw_cpu" =~ ^[0-9]+$ ]] && rem_cpu=$((host_cpus - raw_cpu))
    [ "$rem_cpu" -lt 0 ] && rem_cpu=0
    echo "${raw_cpu} / ${rem_cpu} / ${host_cpus} Core$([ "$host_cpus" = "1" ] || echo s)"
  else
    echo "${host_cpus} / ${host_cpus} / ${host_cpus} Core$([ "$host_cpus" = "1" ] || echo s)"
  fi
}
