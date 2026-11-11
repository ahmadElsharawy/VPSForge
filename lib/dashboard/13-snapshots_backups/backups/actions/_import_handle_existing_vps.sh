#!/bin/bash
# Prompt user when importing over an existing instance to rename, overwrite, or cancel.
_import_handle_existing_vps() {
  local c
  echo "WARNING: Instance '$target_name' currently exists on this server."
  echo "0) Cancel (Default)"
  echo "1) Import under a different name"
  echo "2) Overwrite / Replace current '$target_name' with backup"
  read -r -p "Choice [0=Cancel, 1-2, Enter=0]: " c
  c="${c:-0}"
  case "$c" in
    1)
      local auto_next suffix_num=1 base_prefix="$target_name" custom_target
      if [[ "$target_name" =~ -[0-9]+$ ]]; then
        base_prefix="${target_name%-*}"
        suffix_num="${target_name##*-}"
        suffix_num=$((10#$suffix_num + 1))
      fi
      auto_next="${base_prefix}-${suffix_num}"
      while incus list -c n --format csv 2>/dev/null | grep -Fxq "$auto_next"; do
        suffix_num=$((suffix_num + 1))
        auto_next="${base_prefix}-${suffix_num}"
      done
      read -r -p "Enter new VPS container name [default: $auto_next]: " custom_target </dev/tty
      custom_target="${custom_target:-$auto_next}"
      if incus list -c n --format csv 2>/dev/null | grep -Fxq "$custom_target"; then
        echo "ERROR: Instance '$custom_target' currently exists on this server. Please choose another name."
        return 1
      else
        target_name="$custom_target"
      fi
      ;;
    2)
      read -r -p "This DELETES the current '$target_name' and replaces it with the backup. Type YES to continue: " c </dev/tty || c=""
      [ "$c" = "YES" ] || { echo "Import cancelled."; return 2; }
      echo "Putting the current $target_name aside (it is deleted only after the import succeeds)..."
      old_ip=$(get_ip "$target_name"); old_port=$(get_port "$old_ip")
      hold_name="${target_name}-replaced-$$"
      caddy_bak="/opt/vpsforge/.replaced-${hold_name}.caddy"
      ;;
    *)
      echo "Import cancelled."
      return 2
      ;;
  esac
  return 0
}
