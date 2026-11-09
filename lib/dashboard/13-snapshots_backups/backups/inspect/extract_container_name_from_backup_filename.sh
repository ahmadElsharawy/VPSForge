#!/bin/bash
extract_container_name_from_backup_filename() {
  local fname="$1" name
  fname=$(basename "$fname")
  if [[ "$fname" == *-backup-* ]]; then
    name="${fname%-backup-*}"
  elif [[ "$fname" == *.tar.gz ]]; then
    name="${fname%.tar.gz}"
  elif [[ "$fname" == *.tar ]]; then
    name="${fname%.tar}"
  else
    name="$fname"
  fi
  echo "$name"
}
