#!/bin/bash
# Gathers and displays configured port-forward rules for a VPS internal IP.
_details_print_port_forwards() {
  local ip="$1" r
  local -a pf_rules=()
  if [ -f "$PORT_FORWARD_RULES_FILE" ] && [ "$ip" != "-" ]; then
    local proto eip eport intip intport proto_upper
    while IFS='|' read -r proto eip eport intip intport; do
      [ "$intip" = "$ip" ] || continue
      proto_upper=$(echo "$proto" | tr '[:lower:]' '[:upper:]')
      pf_rules+=("$proto_upper ${eip:-0.0.0.0}:$eport -> $intip:$intport")
    done < "$PORT_FORWARD_RULES_FILE"
  fi

  echo "── Configured Port-Forward Rules (${#pf_rules[@]}) ──────────────────────"
  if [ "${#pf_rules[@]}" -gt 0 ]; then
    for r in "${pf_rules[@]}"; do
      echo "  • $r"
    done
  else
    echo "  None"
  fi
  echo
}
