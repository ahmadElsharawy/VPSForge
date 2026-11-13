#!/bin/bash
# Ask which Linux distribution the new VPS should run (defaults to your last choice).
# Sets SELECTED_DISTRO. Returns 1 when the user chooses Back.
ask_distro() {
  local target="$1" choice idx default_index=1 last_distro mark
  local -a names=(ubuntu debian alpine rockylinux almalinux fedora archlinux centos)
  local -a labels=(
    "Ubuntu        (best compatibility)"
    "Debian        (stable and lightweight)"
    "Alpine        (tiny: about 10MB RAM, best for weak servers)"
    "Rocky Linux   (RHEL compatible)"
    "AlmaLinux     (RHEL compatible)"
    "Fedora        (newest packages)"
    "Arch Linux    (rolling release)"
    "CentOS Stream"
  )

  last_distro=$(pref_get distro ubuntu)
  for idx in "${!names[@]}"; do
    [ "${names[$idx]}" = "$last_distro" ] && default_index=$((idx + 1))
  done

  echo "----------------------------------------------------------------"
  echo "Operating system for $target:"
  echo "0) Back"
  for idx in "${!names[@]}"; do
    mark=""
    [ "$((idx + 1))" = "$default_index" ] && mark="   <- last used"
    printf '%2d) %s%s\n' "$((idx + 1))" "${labels[$idx]}" "$mark"
  done
  read -r -p "Choice [0=Back, Enter=$default_index]: " choice </dev/tty
  choice="${choice:-$default_index}"
  [ "$choice" = "0" ] && return 1
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#names[@]}" ]; then
    SELECTED_DISTRO="${names[$((choice - 1))]}"
    pref_set distro "$SELECTED_DISTRO"
    return 0
  fi
  echo "Invalid choice."
  return 1
}
