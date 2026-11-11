#!/bin/bash
# Display creation summary table and prompt for confirmation.
_add_confirm_summary() {
  clear
  echo "================================================================"
  echo "                VPS CREATION SUMMARY CONFIRMATION"
  echo "================================================================"
  local idx
  for ((idx=0; idx<${#names[@]}; idx++)); do
    _add_print_container_summary "$idx"
  done

  local confirm_input
  read -r -p "Proceed with VPS creation? [Y/n, Enter=Y, 0=Back]: " confirm_input </dev/tty
  confirm_input="${confirm_input:-y}"
  if [ "$confirm_input" = "0" ] || [[ "${confirm_input,,}" =~ ^n ]]; then
    echo "Creation postponed."
    return 1
  fi
  return 0
}
