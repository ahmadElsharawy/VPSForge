#!/bin/bash
# Saves user-configured total host network speed in Mbit to /opt/vpsforge/network_speed_mbit.
set_total_network_mbit() {
  local speed="$1"
  mkdir -p /opt/vpsforge 2>/dev/null || true
  echo "$speed" > /opt/vpsforge/network_speed_mbit
}
