#!/bin/bash
# Print the numbered list of available image versions with friendly release names.
_display_image_options() {
  local distro="$1" target="$2" default_sel="$3"
  shift 3
  local -a images=("$@")
  local idx=1 img label

  echo "Available $distro versions for $target:"
  for img in "${images[@]}"; do
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
}
