#!/bin/bash
# Port-forward wizard step 2 of 5: the port people connect to on the server (Enter repeats your last one).
_pf_step_ext_port() {
  local port last
  last=$(pref_get pf_ext_port "")
  echo
  echo "Step 2 of 5 - Which port should be opened on the server?"
  while :; do
    read -r -p "External Port (e.g. 8080)${last:+ [Enter=$last]} [0=Back]: " port </dev/tty
    [ "$port" = "0" ] && return "$WIZARD_BACK"
    port="${port:-$last}"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
      PF_EXT_PORT="$port"
      pref_set pf_ext_port "$port"
      return 0
    fi
    echo "Invalid port. Must be between 1 and 65535."
  done
}
