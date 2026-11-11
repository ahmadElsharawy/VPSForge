#!/bin/bash
# Accepts "1,2", "1-3", "test2", "vps1", "1 2", or "all"/"A" and populates SELECTED_VPS array.
normalize_selection() {
  local raw="$1" token name
  SELECTED_VPS=()

  if [[ "${raw,,}" == "a" ]] || [[ "${raw,,}" == "all" ]]; then
    mapfile -t SELECTED_VPS < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' | sort -V || true)
  else
    raw="${raw//,/ }"
    for token in $raw; do
      token="${token//[[:space:]]/}"
      [ -z "$token" ] && continue

      if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        _expand_selection_range "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        continue
      fi

      name=$(_resolve_vps_token "$token")

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
