#!/bin/bash
parse_number_selection() {
  local raw="$1" max_val="$2" token start end i
  SELECTED_NUMS=()

  [ -z "$raw" ] && return 1
  if [ "$raw" = "0" ]; then return 1; fi

  if [[ "${raw,,}" == "a" ]] || [[ "${raw,,}" == "all" ]]; then
    for ((i=1; i<=max_val; i++)); do
      SELECTED_NUMS+=("$i")
    done
    return 0
  fi

  raw="${raw//,/ }"
  for token in $raw; do
    token="${token//[[:space:]]/}"
    [ -z "$token" ] && continue

    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      start="${BASH_REMATCH[1]}"
      end="${BASH_REMATCH[2]}"
      if [ "$start" -le "$end" ]; then
        for ((i=start; i<=end; i++)); do
          if [ "$i" -ge 1 ] && [ "$i" -le "$max_val" ]; then
            [[ " ${SELECTED_NUMS[*]} " == *" $i "* ]] || SELECTED_NUMS+=("$i")
          fi
        done
      fi
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      if [ "$token" -ge 1 ] && [ "$token" -le "$max_val" ]; then
        [[ " ${SELECTED_NUMS[*]} " == *" $token "* ]] || SELECTED_NUMS+=("$token")
      fi
    fi
  done

  [ "${#SELECTED_NUMS[@]}" -gt 0 ]
}
