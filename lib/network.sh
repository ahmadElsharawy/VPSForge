#!/bin/bash
# VPSForge — Network management, IP allocation, SSH, and DNS.

# ── Global Network State ─────────────────────────────────────────────────────
# These variables are populated by get_network_info() / get_public_ip()
# and consumed throughout VPSForge.

INCUS_CIDR=""
INCUS_GATEWAY=""
INCUS_NETMASK=""
NETWORK_PREFIX=""
PUBLIC_IP=""

# ── Network Info ─────────────────────────────────────────────────────────────

get_network_info() {
  INCUS_CIDR=$(incus network get incusbr0 ipv4.address 2>/dev/null || true)
  [ -n "$INCUS_CIDR" ] && [ "$INCUS_CIDR" != "none" ] || { echo "incusbr0 has no IPv4."; exit 1; }
  INCUS_GATEWAY="${INCUS_CIDR%/*}"
  INCUS_NETMASK="${INCUS_CIDR#*/}"
  IFS='.' read -r A B C D <<< "$INCUS_GATEWAY"
  NETWORK_PREFIX="$A.$B.$C"
}

get_public_ip() {
  PUBLIC_IP=$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo Unknown)
}

# ── IP Queries ───────────────────────────────────────────────────────────────

get_ip() {
  local ip
  ip=$(incus config get "$1" user.vpsforge.ip 2>/dev/null || true)
  if [ -n "$ip" ]; then
    echo "$ip"
    return
  fi

  incus query "/1.0/instances/$1/state" 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    network = data.get("network", {})
    eth0 = network.get("eth0", {})
    for addr in eth0.get("addresses", []):
        if addr.get("family") == "inet":
            print(addr.get("address"))
            break
except Exception:
    pass
'
}

get_vps_name_by_ip() {
  local target_ip="$1" n ip
  [ -z "$target_ip" ] && return 1
  while read -r n; do
    [ -z "$n" ] && continue
    ip=$(get_ip "$n" 2>/dev/null || true)
    if [ "$ip" = "$target_ip" ]; then
      echo "$n"
      return 0
    fi
  done < <(incus list -c n --format csv 2>/dev/null | grep -E "^${VPS_PREFIX}[0-9]+$" || true)
  return 1
}

get_port() {
  local ip="$1"; [ -z "$ip" ] && return
  iptables -t nat -L PREROUTING -n 2>/dev/null |
    awk -v ip="$ip" '$0 ~ "to:" ip ":22" {for(i=1;i<=NF;i++) if($i~/^dpt:/){sub(/^dpt:/,"",$i);print $i;exit}}'
}

# ── Port Management ──────────────────────────────────────────────────────────

remove_port() {
  local port="$1" line
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null |
      awk -v p="$port" '$0 ~ "dpt:" p {print $1;exit}')
    [ -z "$line" ] && break
    iptables -t nat -D PREROUTING "$line"
  done
}

remove_ip() {
  local ip="$1" line; [ -z "$ip" ] && return
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null |
      awk -v ip="$ip" '$0 ~ "to:" ip ":22" {print $1;exit}')
    [ -z "$line" ] && break
    iptables -t nat -D PREROUTING "$line"
  done
}

free_port() {
  local p=$((SSH_PORT_BASE + 1))
  while iptables -t nat -L PREROUTING -n 2>/dev/null | grep -qE "dpt:${p}([^0-9]|$)"; do
    p=$((p+1))
  done
  echo "$p"
}

vps_fixed_port() {
  local num="$1"
  echo $((SSH_PORT_BASE + num))
}

check_fixed_port_available() {
  local name="$1" ip="$2" port="$3" owner_ip
  owner_ip=$(iptables -t nat -L PREROUTING -n 2>/dev/null | awk -v p="$port" '
    $0 ~ "dpt:" p "([^0-9]|$)" {
      if (match($0,/to:([0-9.]+):22/,m)) print m[1]
      exit
    }' 2>/dev/null || true)

  if [ -n "$owner_ip" ] && [ "$owner_ip" != "$ip" ]; then
    echo "ERROR: Required port $port for $name is already assigned to $owner_ip."
    return 1
  fi
  return 0
}

# ── SSH Forwarding ───────────────────────────────────────────────────────────

add_forward_rule() {
  local ip="$1" port="$2"
  remove_port "$port"
  remove_ip "$ip"
  iptables -t nat -A PREROUTING ! -i incusbr0 -p tcp --dport "$port" -j DNAT --to-destination "${ip}:22"
  iptables -C FORWARD -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -p tcp -d "$ip" --dport 22 -j ACCEPT
  save_iptables
}

ensure_ssh_ready() {
  local name="$1"
  incus exec "$name" -- bash -c '
    export DEBIAN_FRONTEND=noninteractive
    command -v sshd >/dev/null 2>&1 || { apt-get update && apt-get install -y openssh-server; }
    mkdir -p /etc/ssh/sshd_config.d
    printf "PermitRootLogin yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/99-root-login.conf
    systemctl enable ssh >/dev/null 2>&1 || true
    systemctl restart ssh
  ' || return 1

  local i
  for i in $(seq 1 30); do
    incus exec "$name" -- bash -c 'ss -lnt 2>/dev/null | grep -qE "[:.]22[[:space:]]"' && return 0
    sleep 1
  done
  return 1
}

# ── Stale Rule Cleanup ───────────────────────────────────────────────────────

cleanup_stale_rules() {
  local line port ip removed=0
  echo "Scanning VPSForge port-forwarding rules..."

  while read -r line; do
    [ -z "$line" ] && continue
    port=$(echo "$line" | sed -n 's/.*dpt:\([0-9]\+\).*/\1/p')
    ip=$(echo "$line" | sed -n 's/.*to:\([0-9.]\+\):22.*/\1/p')
    [ -z "$port" ] || [ -z "$ip" ] && continue

    # Only manage VPSForge's own SSH port range and current Incus subnet.
    [[ "$port" =~ ^[0-9]+$ ]] || continue
    [ "$port" -ge $((SSH_PORT_BASE + 1)) ] || continue
    [[ "$ip" == "${NETWORK_PREFIX}."* ]] || continue

    local found=0 n current_ip
    while read -r n; do
      [ -z "$n" ] && continue
      current_ip=$(get_ip "$n")
      if [ "$current_ip" = "$ip" ]; then found=1; break; fi
    done < <(incus list -c n --format csv | grep -E "^${VPS_PREFIX}[0-9]+$" || true)

    if [ "$found" -eq 0 ]; then
      echo "Removing stale rule: port $port -> $ip:22"
      remove_port "$port"
      removed=$((removed+1))
    fi
  done < <(iptables -t nat -L PREROUTING -n 2>/dev/null | grep -E "dpt:[0-9]+.*to:${NETWORK_PREFIX}\.[0-9]+:22" || true)

  save_iptables
  echo "Cleanup complete. Removed $removed stale rule(s)."
}

# ── Guest Network Configuration ─────────────────────────────────────────────

wait_guest_eth0() {
  local name="$1" i
  for i in $(seq 1 30); do
    incus exec "$name" -- ip link show dev eth0 >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

apply_guest_static_network() {
  local name="$1" ip="$2" gateway="$3" prefix="${4:-24}"

  if incus exec "$name" -- bash -lc 'command -v netplan >/dev/null 2>&1'; then
    if ! incus exec "$name" -- bash -lc '
      set -e
      mkdir -p /etc/netplan
      cat > /etc/netplan/99-vpsforge.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - '"$ip"'/'"$prefix"'
      routes:
        - to: default
          via: '"$gateway"'
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
EOF
      chmod 600 /etc/netplan/99-vpsforge.yaml
      netplan generate >/dev/null 2>&1 || true
    '; then
      echo "WARNING: Could not generate persistent netplan config in $name; using direct IPv4 setup for this boot."
    fi
  fi

  incus exec "$name" -- bash -lc '
    set -e
    ip link set eth0 up
    ip -4 addr flush dev eth0 scope global || true
    ip -4 addr add '"$ip"'/'"$prefix"' dev eth0
    ip route replace default via '"$gateway"' dev eth0
    ip -4 addr show dev eth0 | grep -Fq -- "'"$ip"'/'"$prefix"'"
    ip -4 route show default | grep -Fq -- "default via '"$gateway"' dev eth0"
  ' || {
    echo "ERROR: ip-based guest network setup failed inside $name."
    return 1
  }

  return 0
}

configure_guest_dns() {
  local name="$1"
  incus exec "$name" -- bash -lc '
    set -e
    rm -f /etc/resolv.conf
    cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
options edns0 trust-ad
EOF
    chmod 644 /etc/resolv.conf
  ' || {
    echo "ERROR: Failed to configure DNS inside $name."
    return 1
  }
}

diagnose_guest_network() {
  local name="$1" ip="${2:-}"

  echo "Guest network diagnostics for $name:"
  incus config show "$name" --expanded 2>/dev/null | awk '
    BEGIN { in_eth0=0 }
    /^[[:space:]]{2}eth0:/ { in_eth0=1; print "  eth0:"; next }
    /^[[:space:]]{2}[a-zA-Z0-9_.-]+:/ {
      if (in_eth0) in_eth0=0
    }
    in_eth0 && /^[[:space:]]{4}/ {
      print "  " $0
    }
  '

  incus exec "$name" -- sh -lc '
    echo "  inside-container routes:"
    ip -4 route || true
    echo "  inside-container addresses:"
    ip -4 addr show dev eth0 2>/dev/null || true
    echo "  inside-container resolv.conf:"
    if [ -r /etc/resolv.conf ]; then cat /etc/resolv.conf
    else echo "    missing /etc/resolv.conf"
    fi
  '

  [ -n "$ip" ] && echo "  expected IPv4: $ip"
}

guest_network_config_ok() {
  local name="$1" ip="${2:-}" gateway="${3:-}" prefix="${4:-24}"
  local route_ok=0 resolv_ok=0 addr_ok=0

  if [ -n "$gateway" ]; then
    incus exec "$name" -- sh -lc 'ip -4 route show default | grep -Fq -- "default via '"$gateway"' dev eth0"' >/dev/null 2>&1
  else
    incus exec "$name" -- sh -lc 'ip -4 route show default | grep -q "^default "' >/dev/null 2>&1
  fi
  route_ok=$?

  incus exec "$name" -- sh -lc 'grep -Fqx "nameserver 1.1.1.1" /etc/resolv.conf && grep -Fqx "nameserver 8.8.8.8" /etc/resolv.conf' >/dev/null 2>&1
  resolv_ok=$?

  if [ -n "$ip" ]; then
    incus exec "$name" -- sh -lc 'ip -4 addr show dev eth0 | grep -Fq -- "'"$ip"'/'"$prefix"'"' >/dev/null 2>&1
    addr_ok=$?
  fi

  [ "$route_ok" -eq 0 ] && [ "$resolv_ok" -eq 0 ] && [ "$addr_ok" -eq 0 ]
}

configure_vps_network_device() {
  local name="$1"
  ensure_device_override "$name" eth0 || return 1
  incus config device unset "$name" eth0 ipv4.address >/dev/null 2>&1 || true
  incus config device unset "$name" eth0 ipv4.gateway >/dev/null 2>&1 || true
  incus config device set "$name" eth0 name eth0 || true
  incus config device set "$name" eth0 network incusbr0 || true
}
