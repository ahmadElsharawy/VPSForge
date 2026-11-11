#!/bin/bash
# Edit an existing port-forward rule by validating new parameters, replacing old rule, and rolling back on failure.
#   _pf_cli_edit <old: proto ext_ip ext_port int_ip int_port> <new: proto ext_ip ext_port int_ip int_port>
_pf_cli_edit() {
  # Old rule (5 values) followed by the new rule (5 values): the old one is
  # removed only after the new one is checked, and comes back if adding fails.
  [ $# -ge 10 ] || { echo "Usage: vpsforge port-forward edit <old: proto ext_ip ext_port int_ip int_port> <new: proto ext_ip ext_port int_ip int_port>"; return 1; }
  local old_rule=("$1" "$2" "$3" "$4" "$5") new_rule=("$6" "$7" "$8" "$9" "${10}")
  local new_proto
  new_proto=$(printf '%s' "${new_rule[0]}" | tr '[:upper:]' '[:lower:]')
  [[ "$new_proto" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
  [[ "${new_rule[2]}" =~ ^[0-9]+$ && "${new_rule[4]}" =~ ^[0-9]+$ ]] || { echo "Ports must be numeric."; return 1; }
  [[ "${new_rule[3]}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "ERROR: the internal address must be an IPv4 address."; return 1; }
  local proto
  for proto in $(resolve_protocols "$new_proto"); do
    is_valid_port_forward_rule "$proto" "${new_rule[1]}" "${new_rule[2]}" "${new_rule[4]}" || { echo "ERROR: invalid new rule (IPv4, ports 1-65535, not 22/80/443). Nothing was changed."; return 1; }
  done
  port_forward_cli delete "${old_rule[@]}" || return 1
  if ! port_forward_cli add "${new_rule[@]}"; then
    echo "Adding the new rule failed; putting the old rule back."
    port_forward_cli add "${old_rule[@]}"
    return 1
  fi
}
