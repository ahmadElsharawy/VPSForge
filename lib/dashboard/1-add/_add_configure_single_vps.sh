#!/bin/bash
# Prompt and configure resources for a single container in the individual wizard.
_add_configure_single_vps() {
  local vps_i="$1" count="$2" n
  n=$((first_num + vps_i - 1))
  local default_name="${VPS_PREFIX}${n}"
  local cur_name="${names[$((vps_i-1))]:-$default_name}"
  local cur_img="${images[$((vps_i-1))]:-}"
  local cur_type="${vps_types[$((vps_i-1))]:-full}"
  local cur_rm="${ram_modes[$((vps_i-1))]:-}"
  local cur_rv="${ram_values[$((vps_i-1))]:-}"
  local cur_cm="${cpu_modes[$((vps_i-1))]:-}"
  local cur_cv="${cpu_values[$((vps_i-1))]:-}"
  local cur_dm="${disk_modes[$((vps_i-1))]:-}"
  local cur_dv="${disk_values[$((vps_i-1))]:-}"
  local cur_nm="${network_modes[$((vps_i-1))]:-}"
  local cur_nv="${network_values[$((vps_i-1))]:-}"
  local cur_trm="${traffic_modes[$((vps_i-1))]:-}"
  local cur_trx="${traffic_rxs[$((vps_i-1))]:-0}"
  local cur_ttx="${traffic_txs[$((vps_i-1))]:-0}"
  local cur_ssh_fwd="${ssh_forwards[$((vps_i-1))]:-}"

  local ind_step=1 custom_name
  while [ $ind_step -ge 1 ] && [ $ind_step -le 8 ]; do
    case "$ind_step" in
      1)
        echo "----------------------------------------------------------------"
        echo "Resources for container $vps_i of $count"
        show_example "web1, test-ubuntu, game-server  (letters, digits and dashes)"
        read -r -p "Enter VPS Name [default: $cur_name, 0=Back]: " custom_name </dev/tty
        if [ "$custom_name" = "0" ]; then
          return 1
        fi
        if [ -n "$custom_name" ]; then cur_name="$custom_name"; fi
        add_name_is_usable "$cur_name" "${names[@]:0:$((vps_i-1))}" || continue
        ind_step=2
        ;;
      2)
        ask_vps_type "$cur_name" || { ind_step=1; continue; }
        cur_type="$VPS_TYPE_RESULT"
        ask_vps_image "$cur_name" || continue
        cur_img="$SELECTED_IMAGE"
        ind_step=3
        ;;
      3)
        ask_ram_mode "$cur_name" || { ind_step=2; continue; }
        cur_rm="$RAM_MODE_RESULT"; cur_rv="${RAM_VALUE_RESULT:-}"
        ind_step=4
        ;;
      4)
        ask_cpu_mode "$cur_name" || { ind_step=3; continue; }
        cur_cm="$CPU_MODE_RESULT"; cur_cv="${CPU_VALUE_RESULT:-}"
        ind_step=5
        ;;
      5)
        ask_disk_mode "$cur_name" || { ind_step=4; continue; }
        cur_dm="$DISK_MODE_RESULT"; cur_dv="${DISK_VALUE_RESULT:-}"
        ind_step=6
        ;;
      6)
        ask_network_mode "$cur_name" || { ind_step=5; continue; }
        cur_nm="$NETWORK_MODE_RESULT"; cur_nv="${NETWORK_VALUE_RESULT:-}"
        ind_step=7
        ;;
      7)
        ask_traffic_mode "$cur_name" || { ind_step=6; continue; }
        cur_trm="$TRAFFIC_MODE_RESULT"; cur_trx="${TRAFFIC_RX_RESULT:-0}"; cur_ttx="${TRAFFIC_TX_RESULT:-0}"
        ind_step=8
        ;;
      8)
        _add_ask_single_ssh_forward "$cur_name" "$n" || { ind_step=7; continue; }
        ind_step=9
        ;;
    esac
  done

  _add_store_single_vps "$vps_i" "$n"
  return 0
}
