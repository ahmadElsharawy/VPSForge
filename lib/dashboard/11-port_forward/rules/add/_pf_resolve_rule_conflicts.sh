#!/bin/bash
# Check if requested port forwarding rule conflicts with existing rules and prompt resolution.
_pf_resolve_rule_conflicts() {
  local proto conflict
  for proto in $(resolve_protocols "$PF_PROTOCOL"); do
    conflict=$(awk -v p="$proto" -v eip="$PF_EXT_IP" -v eport="$PF_EXT_PORT" -v intip="$PF_INTERNAL_IP" -v intport="$PF_INT_PORT" -F'|' '
      BEGIN { if (eip == "" || eip == "any") eip = "0.0.0.0" }
      {
        r_eip = $2; if (r_eip == "" || r_eip == "any") r_eip = "0.0.0.0";
        if ($1 == p && r_eip == eip && $3 == eport && !($4 == intip && $5 == intport)) {
          print $4 "|" $5; exit
        }
      }
    ' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)

    if [ -n "$conflict" ]; then
      _pf_prompt_conflict_action "$proto" "$conflict" || return 1
    fi
  done
  return 0
}
