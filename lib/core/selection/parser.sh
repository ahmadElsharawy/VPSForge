#!/bin/bash
# VPSForge v1.0.0 — Selection parsing and normalization.

# ── Universal Number Selection Parser ────────────────────────────────────────
# Accepts "1,2", "1-4", "1 2 3", or "A"/"all" up to max_val.
# Populates SELECTED_NUMS array.
SELECTED_NUMS=()

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

# ── Normalize Selection ──────────────────────────────────────────────────────

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
