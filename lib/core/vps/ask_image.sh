#!/bin/bash
# VPSForge v1.0.0 — VPS image selection prompt logic.

ask_ubuntu_version() {
  local target="$1"
  fetch_available_ubuntu_images

  local -a img_list=()
  if [ -f "$UBUNTU_IMAGES_CACHE_FILE" ]; then
    mapfile -t img_list < "$UBUNTU_IMAGES_CACHE_FILE"
  fi

  if [ "${#img_list[@]}" -eq 0 ]; then
    echo "No Ubuntu images found. Using default: $VPS_IMAGE"
    SELECTED_IMAGE="$VPS_IMAGE"
    return 0
  fi

  echo "Available Ubuntu versions for $target:"
  local idx=1
  for img in "${img_list[@]}"; do
    local label="${img#images:ubuntu/}"
    local display_label="$label"
    if [[ "$label" =~ ^noble(/cloud)?$ ]]; then
      display_label="24.04${BASH_REMATCH[1]} (noble)"
    elif [[ "$label" =~ ^jammy(/cloud)?$ ]]; then
      display_label="22.04${BASH_REMATCH[1]} (jammy)"
    elif [[ "$label" =~ ^focal(/cloud)?$ ]]; then
      display_label="20.04${BASH_REMATCH[1]} (focal)"
    elif [[ "$label" =~ ^bionic(/cloud)?$ ]]; then
      display_label="18.04${BASH_REMATCH[1]} (bionic)"
    fi

    if [ "$idx" -eq 1 ]; then
      printf "   %2d) %-30s (default)\n" "$idx" "$display_label"
    else
      printf "   %2d) %-30s\n" "$idx" "$display_label"
    fi
    idx=$((idx + 1))
  done

  local default_sel="${img_list[0]:-$VPS_IMAGE}"
  local choice
  read -r -p "Choice [Enter=default ($default_sel)]: " choice </dev/tty
  if [ -z "$choice" ]; then
    SELECTED_IMAGE="$default_sel"
  elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#img_list[@]}" ]; then
    SELECTED_IMAGE="${img_list[$((choice - 1))]}"
  else
    echo "Invalid choice."
    return 1
  fi
  return 0
}
