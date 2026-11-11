#!/bin/bash
# Display preview details of a VPS container prior to backup export and confirm.
_export_vps_backup_preview() {
  local name="$1" ip port ram cpu image pfs proxy_b64 domains confirm

  ip=$(get_ip "$name" 2>/dev/null || echo "-")
  port=$(get_vps_saved_port "$name" 2>/dev/null || echo "-")
  ram=$(incus config get "$name" limits.memory 2>/dev/null || true); ram="${ram:-Unlimited}"
  cpu=$(incus config get "$name" limits.cpu 2>/dev/null || true); cpu="${cpu:-Unlimited}"
  image=$(incus config get "$name" user.vpsforge.image 2>/dev/null || true); image="${image:-Ubuntu}"
  pfs=$(incus config get "$name" user.vpsforge.port_forwards.summary 2>/dev/null || true); pfs="${pfs:-None}"
  proxy_b64=$(incus config get "$name" user.vpsforge.proxy 2>/dev/null || echo "-")

  domains="None"
  if [ -n "$proxy_b64" ] && [ "$proxy_b64" != "-" ]; then
    local proxy_decoded
    proxy_decoded=$(echo "$proxy_b64" | base64 -d 2>/dev/null || true)
    domains=$(echo "$proxy_decoded" | awk '/\{/{print $1}' | tr '\n' ' ' | sed 's/ *$//')
    [ -n "$domains" ] || domains="Configured"
  fi

  clear
  echo "================================================"
  echo "            BACKUP PREVIEW: $name"
  echo "================================================"
  echo "VPS Name:        $name"
  echo "Internal IP:     $ip"
  echo "SSH Port:        $port"
  echo "RAM Limit:       $ram"
  echo "CPU Limit:       $cpu"
  echo "OS Image:        $image"
  echo "Forwarded Ports: $(echo "$pfs" | tr ';' ' ')"
  echo "Linked Domains:  $domains"
  echo "================================================"

  read -r -p "Press Enter to proceed with backup (or '0' to cancel): " confirm </dev/tty
  if [ "$confirm" = "0" ]; then
    echo "Backup cancelled."
    return 1
  fi
  return 0
}
