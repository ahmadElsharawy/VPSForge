#!/bin/bash
# Run a per-VPS edit function (for example edit_change_port) for every selected VPS, one after another.
#   edit_each_selected <function>
edit_each_selected() {
  local fn="${1:?function}" n
  for n in "${SELECTED_VPS[@]}"; do
    [ "${#SELECTED_VPS[@]}" -gt 1 ] && echo "--- $n ---"
    "$fn" "$n"
  done
}
