#!/bin/bash
# Resolve protocol alias ("both" expands to "tcp udp").
resolve_protocols() {
  case "$1" in
    both) echo "tcp udp";;
    *)    echo "$1";;
  esac
}
