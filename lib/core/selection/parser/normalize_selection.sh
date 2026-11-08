#!/bin/bash
# Accepts "1,2", "1-3", "test2", "vps1", "1 2", or "all"/"A" and populates SELECTED_VPS array.
normalize_selection() {
  local raw="$1" token name idx start end i
  SELECTED_VPS=()

  if [[ "${raw,,}" == "a" ]] || [[ "${raw,,}" == "all" ]]; then
    mapfile -t SELECTED_VPS < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' | sort -V || true)
  else
    raw="${raw//,/ }"
    for token in $raw; do
      token="${token//[[:space:]]/}"
      [ -z "$token" ] && continue

      # Range expansion like 1-3
      if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        start="${BASH_REMATCH[1]}"
        end="${BASH_REMATCH[2]}"
        if [ "$start" -le "$end" ]; then
          for ((i=start; i<=end; i++)); do
            if [ "$i" -ge 1 ] && [ "$i" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
              idx=$((i - 1))
              name="${AVAILABLE_VPS_LIST[$idx]}"
              [[ " ${SELECTED_VPS[*]} " == *" $name "* ]] || SELECTED_VPS+=("$name")
            fi
          done
        fi
        continue
      fi

      # Try token as a 1-based index from AVAILABLE_VPS_LIST
      if [[ "$token" =~ ^[0-9]+$ ]] && [ "$token" -ge 1 ] && [ "$token" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
        idx=$((token - 1))
        name="${AVAILABLE_VPS_LIST[$idx]}"
      else
        if [[ "$token" =~ ^[0-9]+$ ]]; then
          name="${VPS_PREFIX}${token}"
        else
          name="$token"
        fi
      fi

      if incus info "$name" >/dev/null 2>&1; then
        [[ " ${SELECTED_VPS[*]} " == *" $name "* ]] || SELECTED_VPS+=("$name")
      else
        echo "Not found: $token ($name)"
        return 1
      fi
    done
  fi

  [ "${#SELECTED_VPS[@]}" -gt 0 ] || { echo "No VPS selected."; return 1; }
}
