#!/bin/bash
# Executes a per-VPS edit function sequentially across all selected VPS instances.
edit_each_selected() {
  local fn="${1:?function}" n
  for n in "${SELECTED_VPS[@]}"; do
    [ "${#SELECTED_VPS[@]}" -gt 1 ] && echo "--- $n ---"
    "$fn" "$n"
  done
}
