#!/bin/bash
# Expands a numeric range (start-end) against AVAILABLE_VPS_LIST and appends to SELECTED_VPS.
_expand_selection_range() {
  local start="$1" end="$2" i idx name
  if [ "$start" -le "$end" ]; then
    for ((i=start; i<=end; i++)); do
      if [ "$i" -ge 1 ] && [ "$i" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
        idx=$((i - 1))
        name="${AVAILABLE_VPS_LIST[$idx]}"
        [[ " ${SELECTED_VPS[*]} " == *" $name "* ]] || SELECTED_VPS+=("$name")
      fi
    done
  fi
}
