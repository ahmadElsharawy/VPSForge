#!/bin/bash
# Prompt for custom or default names for all containers when using shared settings.
_add_shared_collect_names() {
  first_num=$(next_num)
  names=(); nums=(); ports=(); images=(); ssh_forwards=()
  ram_modes=(); ram_values=(); cpu_modes=(); cpu_values=()
  disk_modes=(); disk_values=(); network_modes=(); network_values=()
  traffic_modes=(); traffic_rxs=(); traffic_txs=()

  local idx n default_name custom_name name port
  for ((idx=1; idx<=count; idx++)); do
    n=$((first_num + idx - 1))
    default_name="${VPS_PREFIX}${n}"
    while :; do
      read -r -p "Enter VPS Name for container $idx [default: $default_name, 0=Back]: " custom_name </dev/tty
      [ "$custom_name" = "0" ] && return 1
      if [ -n "$custom_name" ]; then name="$custom_name"; else name="$default_name"; fi
      add_name_is_usable "$name" "${names[@]}" && break
    done
    port=$(vps_fixed_port "$n")
    names+=("$name"); nums+=("$n"); ports+=("$port"); images+=("$shared_img"); vps_types+=("$shared_type"); ssh_forwards+=("$shared_ssh_fwd")
    ram_modes+=("$shared_rm"); ram_values+=("$shared_rv")
    cpu_modes+=("$shared_cm"); cpu_values+=("$shared_cv")
    disk_modes+=("$shared_dm"); disk_values+=("$shared_dv")
    network_modes+=("$shared_nm"); network_values+=("$shared_nv")
    traffic_modes+=("$shared_trm"); traffic_rxs+=("$shared_trx"); traffic_txs+=("$shared_ttx")
  done
}
