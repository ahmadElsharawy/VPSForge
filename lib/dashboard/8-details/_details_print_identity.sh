#!/bin/bash
# Displays header, traffic status warning, and System & Identity details for a VPS.
_details_print_identity() {
  local name="$1" ip="$2"
  local status port username created_at traffic_status

  status=$(get_state "$name" 2>/dev/null || true); [ -n "$status" ] || status="-"
  if [ "$ip" != "-" ]; then
    port=$(get_port "$ip" 2>/dev/null || true)
  else
    port=""
  fi
  [ -n "$port" ] || port=$(get_vps_saved_port "$name" 2>/dev/null || true)
  [ -n "$port" ] || port="-"
  username=$(get_vps_user "$name" 2>/dev/null || true); [ -n "$username" ] || username="-"
  created_at=$(incus query "/1.0/instances/$name" 2>/dev/null | python3 -c 'import sys, json; print(json.load(sys.stdin).get("created_at","")[:19].replace("T"," "))' 2>/dev/null || true)
  [ -n "$created_at" ] || created_at="Unknown"
  traffic_status=$(incus config get "$name" user.vpsforge.traffic.status 2>/dev/null || true)

  echo "================================================================"
  echo "                VPS DETAILS INSPECTOR: $name"
  echo "================================================================"
  if [ -n "$traffic_status" ]; then
    echo "⚠️  WARNING: TRAFFIC QUOTA EXCEEDED! Status: $traffic_status"
    echo "----------------------------------------------------------------"
  fi
  echo "── System & Identity ───────────────────────────────────────────"
  echo "  Name:           $name"
  echo "  Status:         $status"
  echo "  Created At:     $created_at"
  echo "  Internal IP:    $ip"
  echo "  SSH Port:       $port"
  echo "  Username:       $username"
  if [ "$port" != "-" ]; then
    echo "  SSH Command:    ssh ${username}@${PUBLIC_IP} -p ${port}"
  fi
  echo
}
