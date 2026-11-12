#!/bin/bash
# Execute creation of all configured VPS containers and report summary.
_add_execute_creations() {
  local ok=0 failed=0 i effective_ram
  for ((i=0; i<${#names[@]}; i++)); do
    effective_ram="${ram_values[$i]:-$MIN_RAM_MB}"
    if VPS_TYPE="${vps_types[$i]:-full}" create_vps "${names[$i]}" "${nums[$i]}" "$effective_ram" "${ports[$i]}" \
        "${ram_modes[$i]}" "${cpu_modes[$i]}" "${cpu_values[$i]}" \
        "${disk_modes[$i]}" "${disk_values[$i]}" "${network_modes[$i]}" "${network_values[$i]}" \
        "${images[$i]:-$VPS_IMAGE}" \
        "${traffic_modes[$i]:-unlimited}" "${traffic_rxs[$i]:-0}" "${traffic_txs[$i]:-0}" \
        "${ssh_forwards[$i]:-y}"; then
      ok=$((ok+1))
    else
      # create_vps already removed everything the failed creation had reserved.
      echo "Creation failed for ${names[$i]} (see the reason above)."
      failed=$((failed+1))
    fi
  done
  echo "Creation summary: Success=$ok | Incomplete/Failed=$failed"
  pause
  return 0
}
