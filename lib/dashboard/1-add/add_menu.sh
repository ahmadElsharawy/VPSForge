#!/bin/bash
# Main wizard menu to add one or multiple VPS containers (shared or individual resource settings).
add_menu() {
  local count=1 setup=1 first_num i n name port custom_name default_name effective_ram
  local shared_img shared_rm shared_rv shared_cm shared_cv shared_dm shared_dv shared_nm shared_nv shared_trm shared_trx shared_ttx shared_ssh_fwd="y"
  local -a names=() nums=() ports=() ram_modes=() ram_values=() cpu_modes=() cpu_values=() disk_modes=() disk_values=() network_modes=() network_values=() traffic_modes=() traffic_rxs=() traffic_txs=() images=() ssh_forwards=()

  # Main wizard loop
  local main_step=1
  while :; do
    case "$main_step" in
      1)
        _add_step_count || return 1
        if [ "$count" -gt 1 ]; then
          main_step=2
        else
          setup=1
          main_step=3
        fi
        continue
        ;;
      2)
        _add_step_setup_mode || { main_step=1; continue; }
        main_step=3
        continue
        ;;
      3)
        if [ "$setup" = "2" ]; then
          _add_shared_wizard || {
            if [ "$count" -gt 1 ]; then main_step=2; else main_step=1; fi
            continue
          }
          _add_shared_collect_names
        else
          _add_individual_wizard || {
            if [ "$count" -gt 1 ]; then main_step=2; else main_step=1; fi
            continue
          }
        fi
        ;;
    esac

    # Pre-creation summary confirmation
    if ! _add_confirm_summary; then
      if [ "$setup" = "2" ]; then main_step=2; else main_step=3; fi
      continue
    fi
    break
  done

  _add_execute_creations
  return 0
}
