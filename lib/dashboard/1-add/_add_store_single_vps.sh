#!/bin/bash
# Store configured settings for an individual VPS container into tracking arrays.
_add_store_single_vps() {
  local vps_i="$1" n="$2" port
  port=$(vps_fixed_port "$n")
  names[$((vps_i-1))]="$cur_name"
  nums[$((vps_i-1))]="$n"
  ports[$((vps_i-1))]="$port"
  images[$((vps_i-1))]="$cur_img"
  vps_types[$((vps_i-1))]="$cur_type"
  ram_modes[$((vps_i-1))]="$cur_rm"
  ram_values[$((vps_i-1))]="$cur_rv"
  cpu_modes[$((vps_i-1))]="$cur_cm"
  cpu_values[$((vps_i-1))]="$cur_cv"
  disk_modes[$((vps_i-1))]="$cur_dm"
  disk_values[$((vps_i-1))]="$cur_dv"
  network_modes[$((vps_i-1))]="$cur_nm"
  network_values[$((vps_i-1))]="$cur_nv"
  traffic_modes[$((vps_i-1))]="$cur_trm"
  traffic_rxs[$((vps_i-1))]="$cur_trx"
  traffic_txs[$((vps_i-1))]="$cur_ttx"
  ssh_forwards[$((vps_i-1))]="$cur_ssh_fwd"
}
