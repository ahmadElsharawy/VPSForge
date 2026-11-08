#!/bin/bash

_pf_interactive_delete() {
  echo
  echo "--- Delete Port Forward Rule ---"
  local total
  total=$(count_port_forward_rules)
  [ "$total" -gt 0 ] || { echo "No rules to delete."; return 1; }

  local rule_input
  read -r -p "Select rule # to delete (e.g. 1, 1,2, 1-3, or A for All, 0=Cancel): " rule_input </dev/tty
  if ! parse_number_selection "$rule_input" "$total"; then
    echo "Cancelled."
    return 0
  fi

  # Sort selected rule numbers in DESCENDING order so deleting higher indices first
  # does not alter the index positions of lower rules.
  local -a sorted_nums
  mapfile -t sorted_nums < <(printf '%s\n' "${SELECTED_NUMS[@]}" | sort -rn)

  local num rule_line protocol ext_ip ext_port int_ip int_port deleted_count=0
  for num in "${sorted_nums[@]}"; do
    rule_line=$(get_port_forward_rule_by_index "$num")
    [ -n "$rule_line" ] || continue
    IFS='|' read -r protocol ext_ip ext_port int_ip int_port <<< "$rule_line"
    port_forward_cli delete "$protocol" "$ext_ip" "$ext_port" "$int_ip" "$int_port" >/dev/null 2>&1
    deleted_count=$((deleted_count+1))
  done

  echo "Successfully deleted $deleted_count port-forward rule(s)."
}
