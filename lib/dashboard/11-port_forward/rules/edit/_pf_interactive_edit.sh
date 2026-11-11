#!/bin/bash
# Interactive wizard to edit an existing port forward rule.
_pf_interactive_edit() {
  echo
  echo "--- Edit Port Forward Rule ---"
  local total
  total=$(count_port_forward_rules)
  [ "$total" -gt 0 ] || { echo "No rules to edit."; return 1; }

  local rule_num old_line
  read -r -p "Select rule # to edit (1-$total, 0=Cancel): " rule_num
  [[ "$rule_num" =~ ^[0-9]+$ ]] && [ "$rule_num" -ge 1 ] && [ "$rule_num" -le "$total" ] || {
    echo "Cancelled."
    return 0
  }

  old_line=$(get_port_forward_rule_by_index "$rule_num")
  [ -n "$old_line" ] || { echo "Rule not found."; return 1; }

  local old_proto old_ext_ip old_ext_port old_int_ip old_int_port
  IFS='|' read -r old_proto old_ext_ip old_ext_port old_int_ip old_int_port <<< "$old_line"

  echo "Editing Rule #$rule_num ($old_proto ${old_ext_ip:-0.0.0.0}:${old_ext_port} -> ${old_int_ip}:${old_int_port}):"

  local new_int_ip="" new_ext_port="" new_int_port="" new_proto="" new_ext_ip=""
  _pf_edit_prompt_values || return 1
  _pf_edit_validate_rule || return 1

  # Remove old rule & add new rule
  port_forward_cli edit "$old_proto" "${old_ext_ip:-0.0.0.0}" "$old_ext_port" "$old_int_ip" "$old_int_port" \
      "$new_proto" "$new_ext_ip" "$new_ext_port" "$new_int_ip" "$new_int_port"
}
