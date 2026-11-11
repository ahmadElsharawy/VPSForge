#!/bin/bash
# Return 0 if the VPS container status is RUNNING.
is_vps_running() {
  local status
  status=$(get_state "${1:-}")
  [ "$status" = "RUNNING" ]
}
