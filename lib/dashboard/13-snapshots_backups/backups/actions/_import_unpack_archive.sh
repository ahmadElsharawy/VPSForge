#!/bin/bash
# Unpack a backup archive into Incus container with progress spinner.
_import_unpack_archive() {
  local file_path="$1" target_name="$2"
  incus import "$file_path" "$target_name" >/dev/null 2>&1 &
  local import_pid=$!
  local progress=0
  local spinner="-\\|/"
  local spin_idx=0

  while kill -0 $import_pid 2>/dev/null; do
    if [ "$progress" -lt 70 ]; then
      printf "\r[ %3d%% ] Extracting backup file...   " "$progress"
      progress=$((progress + 1))
    else
      printf "\r[  70%% ] Extracting backup file... %c " "${spinner:$spin_idx:1}"
      spin_idx=$(( (spin_idx + 1) % 4 ))
    fi
    sleep 0.5
  done
  wait $import_pid
  if [ $? -ne 0 ]; then
    printf "\r[ FAILED ] Extracting backup file...       \n"
    echo "ERROR: incus could not unpack the backup file (corrupt file or not enough disk space)."
    return 1
  fi
  printf "\r[  70%% ] Extracting backup file... Done!    \n"
  return 0
}
