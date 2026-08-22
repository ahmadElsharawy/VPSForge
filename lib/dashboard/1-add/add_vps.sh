#!/bin/bash

add_menu() {
  local count=1 setup=1 first_num i n name port custom_name default_name effective_ram
  local shared_img shared_rm shared_rv shared_cm shared_cv shared_dm shared_dv shared_nm shared_nv shared_trm shared_trx shared_ttx shared_ssh_fwd="y"
  local -a names=() nums=() ports=() ram_modes=() ram_values=() cpu_modes=() cpu_values=() disk_modes=() disk_values=() network_modes=() network_values=() traffic_modes=() traffic_rxs=() traffic_txs=() images=() ssh_forwards=()

  # Main wizard loop
  local main_step=1
  while :; do
    case "$main_step" in
      1)
        # Step 1: Count
        read -r -p "How many VPS containers do you want to add? [0=Cancel, Enter=1]: " count </dev/tty
        count="${count:-1}"
        if [ "$count" = "0" ]; then
          echo "Cancelled."
          return 1
        fi
        if ! [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
          echo "Invalid count."
          continue
        fi
        if [ "$count" -gt 1 ]; then
          main_step=2
        else
          setup=1
          main_step=3
        fi
        continue
        ;;
      2)
        # Step 2: Setup mode (for count > 1)
        echo "0) Back / Cancel"
        echo "1) Configure each VPS individually (Default)"
        echo "2) Same resource settings for all"
        read -r -p "Choice [0=Back, Enter=1]: " setup </dev/tty
        setup="${setup:-1}"
        if [ "$setup" = "0" ]; then
          main_step=1
          continue
        fi
        if ! [[ "$setup" =~ ^[12]$ ]]; then
          echo "Invalid choice."
          continue
        fi
        main_step=3
        continue
        ;;
      3)
        # Step 3: Configure resources
        if [ "$setup" = "2" ]; then
          # Shared configuration wizard
          local s_step=1
          while [ $s_step -ge 1 ] && [ $s_step -le 7 ]; do
            case "$s_step" in
              1)
                ask_ubuntu_version "all new VPS containers" || { s_step=$((s_step-1)); continue; }
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
                echo "----------------------------------------------------------------"
                echo "SSH Port Forwarding for all new containers:"
                read -r -p "Forward external SSH Port (Port -> 22) for all VPS? [Y/n, Enter=Y, 0=Back]: " shared_ssh_fwd </dev/tty
                if [ "$shared_ssh_fwd" = "0" ]; then
                  s_step=6
                  continue
                fi
                shared_ssh_fwd="${shared_ssh_fwd:-y}"
                if [[ "${shared_ssh_fwd,,}" =~ ^n ]]; then
                  shared_ssh_fwd="n"
                else
                  shared_ssh_fwd="y"
                fi
                s_step=8
                ;;
            esac
          done

          if [ $s_step -lt 1 ]; then
            # User pressed 0 on step 1 of shared config -> go back to setup or count
            if [ "$count" -gt 1 ]; then main_step=2; else main_step=1; fi
            continue
          fi

          # Collect names for all containers
          first_num=$(next_num)
          names=(); nums=(); ports=(); images=(); ssh_forwards=()
          ram_modes=(); ram_values=(); cpu_modes=(); cpu_values=()
          disk_modes=(); disk_values=(); network_modes=(); network_values=()
          traffic_modes=(); traffic_rxs=(); traffic_txs=()

          for ((i=1; i<=count; i++)); do
            n=$((first_num + i - 1))
            default_name="${VPS_PREFIX}${n}"
            read -r -p "Enter VPS Name for container $i [default: $default_name]: " custom_name </dev/tty
            if [ -n "$custom_name" ]; then name="$custom_name"; else name="$default_name"; fi
            port=$(vps_fixed_port "$n")
            names+=("$name"); nums+=("$n"); ports+=("$port"); images+=("$shared_img"); ssh_forwards+=("$shared_ssh_fwd")
            ram_modes+=("$shared_rm"); ram_values+=("$shared_rv")
            cpu_modes+=("$shared_cm"); cpu_values+=("$shared_cv")
            disk_modes+=("$shared_dm"); disk_values+=("$shared_dv")
            network_modes+=("$shared_nm"); network_values+=("$shared_nv")
            traffic_modes+=("$shared_trm"); traffic_rxs+=("$shared_trx"); traffic_txs+=("$shared_ttx")
          done
        else
          # Individual configuration wizard (setup == 1)
          first_num=$(next_num)
          names=(); nums=(); ports=(); images=(); ssh_forwards=()
          ram_modes=(); ram_values=(); cpu_modes=(); cpu_values=()
          disk_modes=(); disk_values=(); network_modes=(); network_values=()
          traffic_modes=(); traffic_rxs=(); traffic_txs=()

          local vps_i=1
          while [ $vps_i -ge 1 ] && [ $vps_i -le $count ]; do
            n=$((first_num + vps_i - 1))
            default_name="${VPS_PREFIX}${n}"
            local cur_name="${names[$((vps_i-1))]:-$default_name}"
            local cur_img="${images[$((vps_i-1))]:-}"
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
            local cur_ssh_fwd="${ssh_forwards[$((vps_i-1))]:-y}"

            local ind_step=1
            while [ $ind_step -ge 1 ] && [ $ind_step -le 8 ]; do
              case "$ind_step" in
                1)
                  echo "----------------------------------------------------------------"
                  echo "Resources for container $vps_i of $count"
                  read -r -p "Enter VPS Name [default: $cur_name, 0=Back]: " custom_name </dev/tty
                  if [ "$custom_name" = "0" ]; then
                    ind_step=0
                    break
                  fi
                  if [ -n "$custom_name" ]; then cur_name="$custom_name"; fi
                  ind_step=2
                  ;;
                2)
                  ask_ubuntu_version "$cur_name" || { ind_step=1; continue; }
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
                  port=$(vps_fixed_port "$n")
                  echo "----------------------------------------------------------------"
                  echo "SSH Port Forwarding for $cur_name (Assigned Port: $port):"
                  read -r -p "Forward external SSH Port ($PUBLIC_IP:$port -> 22)? [Y/n, Enter=Y, 0=Back]: " cur_ssh_fwd </dev/tty
                  if [ "$cur_ssh_fwd" = "0" ]; then
                    ind_step=7
                    continue
                  fi
                  cur_ssh_fwd="${cur_ssh_fwd:-y}"
                  if [[ "${cur_ssh_fwd,,}" =~ ^n ]]; then
                    cur_ssh_fwd="n"
                  else
                    cur_ssh_fwd="y"
                  fi
                  ind_step=9
                  ;;
              esac
            done

            if [ $ind_step -eq 0 ]; then
              # User pressed 0 on VPS Name prompt
              vps_i=$((vps_i - 1))
              continue
            fi

            port=$(vps_fixed_port "$n")
            names[$((vps_i-1))]="$cur_name"
            nums[$((vps_i-1))]="$n"
            ports[$((vps_i-1))]="$port"
            images[$((vps_i-1))]="$cur_img"
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
            vps_i=$((vps_i + 1))
          done

          if [ $vps_i -lt 1 ]; then
            # Backed out past container 1 -> go back to setup or count
            if [ "$count" -gt 1 ]; then main_step=2; else main_step=1; fi
            continue
          fi
        fi
        ;;
    esac

    # Pre-creation summary confirmation
    clear
    echo "================================================================"
    echo "                VPS CREATION SUMMARY CONFIRMATION"
    echo "================================================================"
    local idx v_ip r_disp c_disp d_disp n_disp t_disp img_disp ssh_disp
    for ((idx=0; idx<${#names[@]}; idx++)); do
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
    done

    local confirm_input
    read -r -p "Proceed with VPS creation? [Y/n, Enter=Y, 0=Back]: " confirm_input </dev/tty
    confirm_input="${confirm_input:-y}"
    if [ "$confirm_input" = "0" ] || [[ "${confirm_input,,}" =~ ^n ]]; then
      echo "Creation postponed."
      if [ "$setup" = "2" ]; then main_step=2; else main_step=3; fi
      continue
    fi
    break
  done

  local ok=0 failed=0
  for ((i=0; i<${#names[@]}; i++)); do
    effective_ram="${ram_values[$i]:-$MIN_RAM_MB}"
    if create_vps "${names[$i]}" "${nums[$i]}" "$effective_ram" "${ports[$i]}" \
        "${ram_modes[$i]}" "${cpu_modes[$i]}" "${cpu_values[$i]}" \
        "${disk_modes[$i]}" "${disk_values[$i]}" "${network_modes[$i]}" "${network_values[$i]}" \
        "${images[$i]:-$VPS_IMAGE}" \
        "${traffic_modes[$i]:-unlimited}" "${traffic_rxs[$i]:-0}" "${traffic_txs[$i]:-0}" \
        "${ssh_forwards[$i]:-y}"; then
      ok=$((ok+1))
    else
      echo "Creation failed for ${names[$i]}. Rolling back incomplete VPS..."
      remove_port "${ports[$i]}" 2>/dev/null || true
      incus delete "${names[$i]}" --force 2>/dev/null || true
      failed=$((failed+1))
    fi
  done
  echo "Creation summary: Success=$ok | Incomplete/Failed=$failed"
  pause
  return 0
}
