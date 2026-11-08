#!/bin/bash
# Port-forward wizard step 1 of 5: which VPS (or custom IP) receives the traffic.
_pf_step_target() {
  local input idx last
  last=$(pref_get pf_target "")
  echo "Step 1 of 5 - Which VPS should receive the traffic?"
  list_available_vps || true
  show_example "1 (first VPS), web1 (by name), or an IP such as 10.0.0.5"
  read -r -p "VPS number, name, or a custom IP address${last:+ [Enter=$last]} [0=Back]: " input </dev/tty
  [ "$input" = "0" ] && return "$WIZARD_BACK"
  input="${input:-$last}"
  [ -n "$input" ] || { echo "Nothing entered."; return 1; }

  if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
    idx=$((input - 1))
    PF_TARGET_VPS="${AVAILABLE_VPS_LIST[$idx]}"
  elif [[ "$input" =~ ^[0-9]+$ ]]; then
    PF_TARGET_VPS="${VPS_PREFIX}${input}"
  else
    PF_TARGET_VPS="$input"
  fi

  if incus info "$PF_TARGET_VPS" >/dev/null 2>&1; then
    PF_INTERNAL_IP=$(get_ip "$PF_TARGET_VPS")
    if [ -z "$PF_INTERNAL_IP" ]; then
      echo "ERROR: $PF_TARGET_VPS is currently stopped or has no IP allocated."
      return 1
    fi
    echo "Selected VPS: $PF_TARGET_VPS (Internal IP: $PF_INTERNAL_IP)"
  elif [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    PF_INTERNAL_IP="$input"
    echo "Using custom IP: $PF_INTERNAL_IP"
  else
    echo "ERROR: Invalid VPS or IP address: $input"
    return 1
  fi
  pref_set pf_target "$input"
  return 0
}
