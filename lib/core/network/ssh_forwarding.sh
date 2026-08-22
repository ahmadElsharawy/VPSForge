#!/bin/bash
# VPSForge v1.0.0 — SSH forwarding and stale rule cleanup.

add_forward_rule() {
  local ip="$1" port="$2"
  remove_port "$port"
  remove_ip "$ip"
  iptables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "${ip}:22"
  iptables -C FORWARD -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -p tcp -d "$ip" --dport 22 -j ACCEPT
  save_iptables

  mkdir -p "$(dirname "$PORT_FORWARD_RULES_FILE")" 2>/dev/null || true
  touch "$PORT_FORWARD_RULES_FILE" 2>/dev/null || true
  if ! grep -q "tcp|0.0.0.0|${port}|${ip}|22" "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
    echo "tcp|0.0.0.0|${port}|${ip}|22" >> "$PORT_FORWARD_RULES_FILE"
  fi
  local name
  name=$(get_vps_name_by_ip "$ip" 2>/dev/null || true)
  [ -n "$name" ] && sync_vps_metadata "$name"
}

ensure_ssh_ready() {
  local name="$1"
  incus exec "$name" -- sh -c '
    set -e
    if ! command -v sshd >/dev/null 2>&1; then
      if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        mkdir -p /etc/apt/apt.conf.d
        printf "Acquire::ForceIPv4 \"true\";\n" > /etc/apt/apt.conf.d/99force-ipv4
        apt-get -o Acquire::ForceIPv4=true update
        apt-get -o Acquire::ForceIPv4=true install -y openssh-server
      elif command -v apk >/dev/null 2>&1; then
        apk update
        apk add --no-cache openssh-server openssh
      elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm openssh
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y openssh-server
      elif command -v yum >/dev/null 2>&1; then
        yum install -y openssh-server
      else
        echo "Unknown package manager."
      fi
    fi

    if [ -d /etc/ssh/sshd_config.d ]; then
      mkdir -p /etc/ssh/sshd_config.d
      printf "PermitRootLogin yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/99-root-login.conf
    else
      mkdir -p /etc/ssh
      touch /etc/ssh/sshd_config
      grep -v -E "^(PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config > /etc/ssh/sshd_config.tmp || true
      mv /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config
      printf "PermitRootLogin yes\nPasswordAuthentication yes\n" >> /etc/ssh/sshd_config
    fi

    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
      systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    elif command -v rc-update >/dev/null 2>&1; then
      rc-update add sshd default 2>/dev/null || true
      /etc/init.d/sshd restart 2>/dev/null || true
    fi
  ' || return 1

  local i
  for i in $(seq 1 30); do
    incus exec "$name" -- sh -c '(ss -lnt 2>/dev/null || netstat -lnt 2>/dev/null) | grep -qE "[:.]22([[:space:]]|$)"' && return 0
    sleep 1
  done
  return 1
}

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
    done < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)

    if [ "$found" -eq 0 ]; then
      echo "Removing stale rule: port $port -> $ip:22"
      remove_port "$port"
      removed=$((removed+1))
    fi
  done < <(iptables -t nat -L PREROUTING -n 2>/dev/null | grep -E "dpt:[0-9]+.*to:${NETWORK_PREFIX}\.[0-9]+:22" || true)

  save_iptables
  echo "Cleanup complete. Removed $removed stale rule(s)."
}
