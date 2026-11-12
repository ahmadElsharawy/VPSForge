#!/bin/bash
# Wizard loop to prompt shared resource settings for all containers.
_add_shared_wizard() {
  local s_step=1
  while [ $s_step -ge 1 ] && [ $s_step -le 7 ]; do
    case "$s_step" in
      1)
        ask_vps_type "all new VPS containers" || { s_step=0; continue; }
        shared_type="$VPS_TYPE_RESULT"
        ask_vps_image "all new VPS containers" || continue
        shared_img="$SELECTED_IMAGE"
        s_step=2
        ;;
      2)
        ask_ram_mode "all new VPS containers" || { s_step=1; continue; }
        shared_rm="$RAM_MODE_RESULT"
        shared_rv="${RAM_VALUE_RESULT:-}"
        s_step=3
        ;;
      3)
        ask_cpu_mode "all new VPS containers" || { s_step=2; continue; }
        shared_cm="$CPU_MODE_RESULT"
        shared_cv="${CPU_VALUE_RESULT:-}"
        s_step=4
        ;;
      4)
        ask_disk_mode "all new VPS containers" || { s_step=3; continue; }
        shared_dm="$DISK_MODE_RESULT"
        shared_dv="${DISK_VALUE_RESULT:-}"
        s_step=5
        ;;
      5)
        ask_network_mode "all new VPS containers" || { s_step=4; continue; }
        shared_nm="$NETWORK_MODE_RESULT"
        shared_nv="${NETWORK_VALUE_RESULT:-}"
        s_step=6
        ;;
      6)
        ask_traffic_mode "all new VPS containers" || { s_step=5; continue; }
        shared_trm="$TRAFFIC_MODE_RESULT"
        shared_trx="${TRAFFIC_RX_RESULT:-0}"
        shared_ttx="${TRAFFIC_TX_RESULT:-0}"
        s_step=7
        ;;
      7)
        _add_ask_shared_ssh_forward || { s_step=6; continue; }
        s_step=8
        ;;
    esac
  done
  [ "$s_step" -ge 8 ]
}
