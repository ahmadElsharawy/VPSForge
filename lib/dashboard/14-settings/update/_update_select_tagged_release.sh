#!/bin/bash
# Fetches repository tags and prompts the user to select and install a tagged release.
_update_select_tagged_release() {
  local repo_dir="$1"
  local -a tags
  local target v_choice

  if [ ! -d "$repo_dir/.git" ]; then
    echo "Initializing repository..."
    vpsforge_perform_update --check >/dev/null 2>&1 || true
  fi
  git -C "$repo_dir" fetch --tags --prune >/dev/null 2>&1 || true
  mapfile -t tags < <(git -C "$repo_dir" tag --sort=-version:refname 2>/dev/null || true)
  if [ "${#tags[@]}" -eq 0 ]; then
    echo "No release tags found. Updating to latest instead..."
    vpsforge_with_update_lock vpsforge_perform_update latest
    pause
    return
  fi

  _update_print_available_tags "${tags[@]}"

  read -r -p "Choose version number, or press Enter to cancel: " v_choice
  [ -n "$v_choice" ] || return
  if [[ "$v_choice" =~ ^[0-9]+$ ]] && [ "$v_choice" -ge 1 ] && [ "$v_choice" -le "${#tags[@]}" ]; then
    target="${tags[$((v_choice-1))]}"
    vpsforge_with_update_lock vpsforge_perform_update "$target"
    pause
  else
    echo "Invalid choice."
    pause
  fi
}
