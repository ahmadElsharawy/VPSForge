#!/bin/bash
# Wizard loop to configure each VPS container individually.
_add_individual_wizard() {
  first_num=$(next_num)
  if [ "${#names[@]}" -ne "$count" ]; then
    names=(); nums=(); ports=(); images=(); ssh_forwards=(); vps_types=()
    ram_modes=(); ram_values=(); cpu_modes=(); cpu_values=()
    disk_modes=(); disk_values=(); network_modes=(); network_values=()
    traffic_modes=(); traffic_rxs=(); traffic_txs=()
  fi

  local vps_i=1
  while [ "$vps_i" -ge 1 ] && [ "$vps_i" -le "$count" ]; do
    if _add_configure_single_vps "$vps_i" "$count"; then
      vps_i=$((vps_i + 1))
    else
      vps_i=$((vps_i - 1))
    fi
  done

  [ "$vps_i" -ge 1 ]
}
