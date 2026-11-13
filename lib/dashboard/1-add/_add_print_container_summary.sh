#!/bin/bash
# Print configuration details for a single container in the summary confirmation.
_add_print_container_summary() {
  local idx="$1" v_ip r_disp c_disp d_disp n_disp t_disp img_disp ssh_disp
  v_ip="${NETWORK_PREFIX}.$((IP_START + ${nums[$idx]} - 1))"
  
  if [ "${ram_modes[$idx]}" = "limited" ]; then r_disp="${ram_values[$idx]}MB"; else r_disp="Unlimited"; fi
  if [ "${cpu_modes[$idx]}" = "limited" ]; then c_disp="${cpu_values[$idx]} Core(s)"; else c_disp="Unlimited"; fi
  if [ "${disk_modes[$idx]}" = "limited" ]; then d_disp="${disk_values[$idx]}GB"; else d_disp="Unlimited"; fi
  if [ "${network_modes[$idx]}" = "limited" ]; then n_disp="${network_values[$idx]} Mbit"; else n_disp="Unlimited"; fi
  if [ "${traffic_modes[$idx]}" = "limited" ]; then
    t_disp="Download: ${traffic_rxs[$idx]}GB | Upload: ${traffic_txs[$idx]}GB"
  else
    t_disp="Unlimited"
  fi
  img_disp="${images[$idx]:-$VPS_IMAGE}"

  if [ "${ssh_forwards[$idx]:-y}" = "y" ]; then
    ssh_disp="Forwarded (${ports[$idx]} -> 22)"
  else
    ssh_disp="Disabled (Internal only :22)"
  fi

  echo "Container $((idx+1)) of ${#names[@]}:"
  echo "  Name:            ${names[$idx]}"
  echo "  Assigned IP:     $v_ip"
  echo "  SSH Port:        ${ports[$idx]}"
  echo "  SSH Forwarding:  $ssh_disp"
  echo "  OS Image:        $img_disp"
  echo "  RAM Limit:       $r_disp"
  echo "  CPU Limit:       $c_disp"
  echo "  Disk Limit:      $d_disp"
  echo "  Network Speed:   $n_disp"
  echo "  Traffic Limit:   $t_disp"
  echo "----------------------------------------------------------------"
}
