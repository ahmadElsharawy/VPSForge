#!/bin/bash
# Print formatted details card for a backup archive.
_inspect_backup_print_details() {
  local file_path="$1" size="$2" mtime="$3" orig_name="$4" orig_ip="$5" orig_port="$6"
  local ram_lim="$7" cpu_lim="$8" os_img="$9" pfs="${10}" proxy_b64="${11}"

  echo "================================================"
  echo "            BACKUP FILE DETAILS"
  echo "================================================"
  echo "File:            $(basename "$file_path")"
  echo "File Size:       $size"
  echo "Creation Time:   $mtime"
  echo "Original VPS:    $orig_name"
  echo "Original IP:     $orig_ip"
  echo "SSH Port:        $orig_port"
  echo "RAM Limit:       $ram_lim"
  echo "CPU Limit:       $cpu_lim"
  echo "OS Image:        $os_img"
  if [ -n "$pfs" ] && [ "$pfs" != "-" ]; then
    echo "Forwarded Ports: $(echo "$pfs" | tr ';' ' ')"
  else
    echo "Forwarded Ports: None"
  fi
  if [ -n "$proxy_b64" ] && [ "$proxy_b64" != "-" ]; then
    local proxy_decoded doms
    proxy_decoded=$(echo "$proxy_b64" | base64 -d 2>/dev/null || true)
    doms=$(echo "$proxy_decoded" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | head -n 1 | sed 's/{//g' | tr ',' ' ' | xargs)
    [ -n "$doms" ] && echo "Linked Domains:  $doms" || echo "Linked Domains:  Configured"
  else
    echo "Linked Domains:  None"
  fi
  echo "================================================"
}
