#!/bin/bash
# Port-forward wizard step 3 of 5: the port inside the VPS (Enter repeats your last one, or the external port the first time).
_pf_step_int_port() {
  local port default
  default=$(pref_get pf_int_port "$PF_EXT_PORT")
  echo
  echo "Step 3 of 5 - Which port inside the VPS?"
  show_example "80  -> the port your app listens on inside the VPS (web servers use 80)"
  while :; do
    read -r -p "Internal Port [Enter = $default, 0=Back]: " port </dev/tty
    [ "$port" = "0" ] && return "$WIZARD_BACK"
    [ -n "$port" ] || port="$default"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
      PF_INT_PORT="$port"
      pref_set pf_int_port "$port"
      return 0
    fi
    echo "Invalid internal port."
  done
}
