#!/bin/bash
# Ask which distribution and release a new VPS should use (both default to your last choice).
# Sets SELECTED_IMAGE. Typing 0 on the release list goes back to the distribution list;
# typing 0 on the distribution list returns 1 (back to the previous wizard step).
ask_vps_image() {
  local target="$1" distro img label idx choice default_sel last_image
  local -a img_list=()

  while :; do
    ask_distro "$target" || return 1
    distro="$SELECTED_DISTRO"

    fetch_available_images "$distro"
    img_list=()
    [ -f "${IMAGE_CACHE_PREFIX}${distro}.txt" ] && mapfile -t img_list < "${IMAGE_CACHE_PREFIX}${distro}.txt"

    if [ "${#img_list[@]}" -eq 0 ]; then
      echo "No $distro images found. Using default: $VPS_IMAGE"
      SELECTED_IMAGE="$VPS_IMAGE"
      return 0
    fi

    # Ubuntu: put the LTS first.
    if [ "$distro" = "ubuntu" ]; then
      local -a ordered=("images:ubuntu/noble")
      for img in "${img_list[@]}"; do [ "$img" = "images:ubuntu/noble" ] || ordered+=("$img"); done
      img_list=("${ordered[@]}")
    fi

    default_sel="${img_list[0]}"
    last_image=$(pref_get "image_${distro}" "")
    for img in "${img_list[@]}"; do [ "$img" = "$last_image" ] && default_sel="$img"; done

    echo "Available $distro versions for $target:"
    idx=1
    for img in "${img_list[@]}"; do
      label="${img#images:}"
      case "$label" in
        ubuntu/noble)  label="ubuntu 24.04 (noble)";;
        ubuntu/jammy)  label="ubuntu 22.04 (jammy)";;
        ubuntu/focal)  label="ubuntu 20.04 (focal)";;
        ubuntu/bionic) label="ubuntu 18.04 (bionic)";;
      esac
      if [ "$img" = "$default_sel" ]; then
        printf "   %2d) %-30s (default, last used)\n" "$idx" "$label"
      else
        printf "   %2d) %-30s\n" "$idx" "$label"
      fi
      idx=$((idx + 1))
    done

    read -r -p "Choice [0=Back, Enter=default ($default_sel)]: " choice </dev/tty
    if [ "${choice:-}" = "0" ]; then
      continue                                   # back to the distribution list
    elif [ -z "$choice" ]; then
      SELECTED_IMAGE="$default_sel"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#img_list[@]}" ]; then
      SELECTED_IMAGE="${img_list[$((choice - 1))]}"
    else
      echo "Invalid choice."
      continue
    fi
    pref_set "image_${distro}" "$SELECTED_IMAGE"
    return 0
  done
}
