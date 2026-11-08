#!/bin/bash
_apply_resource_limit() {
  local name="$1" resource="$2" mode="$3" value="$4"
  case "$resource" in
    ram)  set_ram_mode_for_vps "$name" "$mode" "$value";;
    cpu)  set_cpu_mode_for_vps "$name" "$mode" "$value";;
    disk) set_disk_mode_for_vps "$name" "$mode" "$value";;
    net)  set_network_mode_for_vps "$name" "$mode" "$value";;
  esac
}
