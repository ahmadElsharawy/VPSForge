#!/bin/bash
# After a VPS is deleted, show the backups that belonged to it and offer to
# delete them too (default: yes) so they do not keep using the server's disk.
delete_vps_backups_prompt() {
  local name="${1:?usage: delete_vps_backups_prompt <name>}" file total_kb=0 count=0 answer
  while read -r file; do
    [ -n "$file" ] || continue
    count=$((count + 1))
    total_kb=$((total_kb + $(du -sk "$file" | cut -f1)))
  done < <(list_backups_for_vps "$name")

  [ "$count" -gt 0 ] || return 0

  echo "  $count backup file(s) of '$name' still use $((total_kb / 1024))MB of the server's disk:"
  list_backups_for_vps "$name" | while read -r file; do
    echo "    - $(basename "$file") ($(du -h "$file" | cut -f1))"
  done
  read -r -p "  Delete these backups too? [Y/n]: " answer </dev/tty
  if [[ "${answer,,}" =~ ^n ]]; then
    echo "  Backups kept (remove later with: vpsforge clean-backups)."
  else
    delete_backups_for_vps "$name"
  fi
}
