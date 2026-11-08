#!/bin/bash
is_vps_running() {
  local s
  s=$(get_state "${1:-}")
  [ "$s" = "RUNNING" ]
}
