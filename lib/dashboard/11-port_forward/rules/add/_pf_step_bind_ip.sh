#!/bin/bash
# Port-forward wizard step 5 of 5: which server address accepts the connections (defaults to your last choice).
_pf_step_bind_ip() {
  local ip last
  last=$(pref_get pf_bind_ip 0.0.0.0)
  echo
  echo "Step 5 of 5 - Which server address accepts connections?"
  read -r -p "External Bind IP [Enter = $last, 0=Back]: " ip </dev/tty
  [ "$ip" = "0" ] && return "$WIZARD_BACK"
  [ -n "$ip" ] || ip="$last"
  PF_EXT_IP="$ip"
  pref_set pf_bind_ip "$ip"
  return 0
}
