#!/bin/bash
# Port-forward wizard step 5 of 5: which server address accepts the connections (defaults to your last choice).
_pf_step_bind_ip() {
  local ip last
  last=$(pref_get pf_bind_ip 0.0.0.0)
  echo
  echo "Step 5 of 5 - Which server address accepts connections?"
  show_example "0.0.0.0 = from everywhere (normal)   or the server IP to allow only that address"
  while :; do
    read -r -p "External Bind IP [Enter = $last, 0=Back]: " ip </dev/tty || return "$WIZARD_BACK"
    [ "$ip" = "0" ] && return "$WIZARD_BACK"
    [ -n "$ip" ] || ip="$last"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && break
    echo "That is not an IPv4 address (example: 0.0.0.0)."
  done
  PF_EXT_IP="$ip"
  pref_set pf_bind_ip "$ip"
  return 0
}
