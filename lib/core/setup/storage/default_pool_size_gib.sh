#!/bin/bash
# Size (GiB) of the BTRFS pool that holds all VPS disks: 70% of the host's free
# space (min 10), so one big cloud VM (Oracle/Google/...) can be split fully
# instead of being capped at a fixed 25GiB.
default_pool_size_gib() {
  local avail size
  avail=$(df -BG --output=avail /var/lib 2>/dev/null | tail -1 | tr -dc '0-9')
  [[ "$avail" =~ ^[0-9]+$ ]] || avail=36
  size=$((avail * 70 / 100))
  [ "$size" -lt 10 ] && size=10
  echo "$size"
}
