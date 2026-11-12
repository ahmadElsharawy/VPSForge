#!/bin/bash
# Load cached backup index metadata or extract it from archive with progress indicator.
_inspect_backup_load_metadata() {
  local file_path="$1"
  local info_path="${file_path}.info"
  if [ -f "$info_path" ]; then
    index_content=$(cat "$info_path" 2>/dev/null || true)
    return 0
  fi

  echo ""
  local tar_pid progress=0 tmp_meta="/tmp/vpsforge_meta_$$.yaml"
  ( tar -xvf "$file_path" backup/index.yaml -O > "$tmp_meta" ) >/dev/null 2>&1 &
  tar_pid=$!

  while kill -0 $tar_pid 2>/dev/null; do
    printf "\r[ %3d%% ] Inspecting backup metadata..." "$progress"
    sleep 1
    if [ "$progress" -lt 99 ]; then
      progress=$((progress + 1))
    fi
  done
  wait $tar_pid
  printf "\r[ 100%% ] Inspecting backup metadata... Done!\n\n"

  index_content=$(cat "$tmp_meta" 2>/dev/null || true)
  rm -f "$tmp_meta" 2>/dev/null

  # Cache it for next time
  if [ -n "$index_content" ]; then
    echo "$index_content" > "$info_path" 2>/dev/null || true
    chmod 600 "$info_path" 2>/dev/null || true
  fi
}
