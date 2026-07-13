#!/bin/bash
set -uo pipefail

VPSFORGE_VERSION="v1.0.0"

# Fast version query
if [[ "${1:-}" == "--version" ]]; then
  echo "$VPSFORGE_VERSION"
  exit 0
fi
VPS_PREFIX="vps"
VPS_IMAGE="images:ubuntu/24.04"
SSH_PORT_BASE=9000
IP_START=11
ROOT_PASSWORD="root"
MIN_RAM_MB=128
PORT_FORWARD_RULES_FILE="/opt/vpsforge/port-forwards.conf"

if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi

pause(){ read -r -p "Press Enter to continue..."; }

ensure_setup() {
  command -v incus >/dev/null 2>&1 || { apt-get update && apt-get install -y incus; }
  command -v iptables >/dev/null 2>&1 || apt-get install -y iptables
  command -v netfilter-persistent >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
  command -v curl >/dev/null 2>&1 || apt-get install -y curl
  incus network show incusbr0 >/dev/null 2>&1 || incus admin init --minimal
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-incus-forwarding.conf
  iptables -C FORWARD -i incusbr0 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -i incusbr0 -j ACCEPT
  iptables -C FORWARD -o incusbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -o incusbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  netfilter-persistent save >/dev/null 2>&1 || true

  # Host-side kernel modules and sysctls required for Docker/containerd/WireGuard/etc.
  # to work correctly inside nested Incus/LXC system containers. This follows the
  # official Incus documentation for running Docker inside system containers.
  ensure_host_kernel_prerequisites
  check_host_compatibility
}

# Loads and persists the kernel modules and sysctl values that the HOST needs so that
# nested workloads (Docker, containerd, WireGuard, nftables, bridging, etc.) work
# correctly inside VPSForge-created containers. These are host-level requirements
# that cannot be satisfied from inside a container, so they are applied here once,
# on the host, the correct way (modprobe + modules-load.d + sysctl.d), with no hacks.
ensure_host_kernel_prerequisites() {
  local mod

  # Kernel modules required for overlayfs-based Docker storage drivers and for
  # bridged networking (br_netfilter) so that iptables/nftables can see bridged traffic.
  for mod in overlay br_netfilter ip_tables ip6_tables iptable_nat ip6table_nat \
             nf_nat nf_conntrack xt_conntrack bridge veth fuse tun; do
    modprobe "$mod" >/dev/null 2>&1 || true
  done

  # Persist module loading across reboots.
  cat > /etc/modules-load.d/vpsforge.conf <<'EOF'
overlay
br_netfilter
ip_tables
ip6_tables
iptable_nat
ip6table_nat
nf_nat
nf_conntrack
xt_conntrack
bridge
veth
fuse
tun
EOF

  # Sysctls required for bridged traffic to traverse iptables/nftables correctly,
  # and to allow IPv4/IPv6 forwarding for routed VPS traffic (Docker, WireGuard,
  # Tailscale, VPN/NAT use-cases inside the guest).
  {
    echo 'net.ipv4.ip_forward=1'
    if [ -e /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
      echo 'net.bridge.bridge-nf-call-iptables=1'
    fi
    if [ -e /proc/sys/net/bridge/bridge-nf-call-ip6tables ]; then
      echo 'net.bridge.bridge-nf-call-ip6tables=1'
    fi
    if [ -e /proc/sys/net/ipv4/conf/all/forwarding ]; then
      echo 'net.ipv4.conf.all.forwarding=1'
    fi
    if [ -e /proc/sys/net/ipv6/conf/all/forwarding ]; then
      echo 'net.ipv6.conf.all.forwarding=1'
    fi
  } > /etc/sysctl.d/99-vpsforge-nesting.conf
  sysctl -p /etc/sysctl.d/99-vpsforge-nesting.conf >/dev/null 2>&1 || true
}

# Checks HOST-level capabilities that VPSForge cannot enable from inside a container.
# Per Incus documentation, some of these must be true on the host kernel/OS itself
# (kernel modules, cgroup mode, AppArmor availability). If something is missing,
# VPSForge does NOT attempt a workaround: it reports the exact gap so the operator
# can fix it on the host, then re-run VPSForge.
check_host_compatibility() {
  local issues=0

  echo "Checking host compatibility for Docker/containerd/WireGuard/etc. workloads..."

  if ! lsmod 2>/dev/null | grep -q '^overlay'; then
    echo "  [MISSING] Kernel module 'overlay' is not loaded. Docker's overlay2 storage driver inside guests may fail."
    echo "            Fix on host: modprobe overlay"
    issues=$((issues+1))
  fi

  if ! lsmod 2>/dev/null | grep -q '^br_netfilter'; then
    echo "  [MISSING] Kernel module 'br_netfilter' is not loaded. iptables/nftables may not see bridged container traffic."
    echo "            Fix on host: modprobe br_netfilter"
    issues=$((issues+1))
  fi

  if [ -e /sys/fs/cgroup/cgroup.controllers ]; then
    :
  else
    echo "  [MISSING] Host is not using unified cgroup v2. Docker/containerd inside guests expect cgroup v2."
    echo "            Fix on host: enable cgroup v2 (systemd.unified_cgroup_hierarchy=1 kernel parameter) and reboot."
    issues=$((issues+1))
  fi

  if [ ! -e /dev/fuse ]; then
    echo "  [MISSING] /dev/fuse is not present on the host. FUSE-based storage/tools inside guests may fail."
    echo "            Fix on host: modprobe fuse"
    issues=$((issues+1))
  fi

  if [ -e /sys/module/apparmor/parameters/enabled ] && [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = "Y" ]; then
    if ! command -v aa-status >/dev/null 2>&1 && [ ! -d /sys/kernel/security/apparmor ]; then
      echo "  [WARNING] AppArmor appears enabled but its securityfs interface is unavailable."
      echo "            VPSForge sets containers to lxc.apparmor.profile=unconfined; verify AppArmor tooling on host if issues occur."
    fi
  fi

  if [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)" != "1" ]; then
    echo "  [MISSING] net.ipv4.ip_forward is not enabled on the host."
    echo "            Fix on host: sysctl -w net.ipv4.ip_forward=1"
    issues=$((issues+1))
  fi

  # Docker's overlay2 storage driver has two well-documented, HOST-level
  # requirements that VPSForge cannot fix from inside a container (per Docker's
  # official "OverlayFS storage driver" documentation):
  #   1) The backing filesystem must not itself be overlayfs (Docker does not
  #      support running overlay2 on top of an existing overlay filesystem).
  #   2) If the backing filesystem is XFS, it must be formatted with ftype=1
  #      (d_type=true), otherwise Docker refuses to use overlay2.
  # This check is read-only: it reports the exact gap, it does not attempt
  # any workaround (no re-formatting, no forced storage driver change).
  local pool pool_source fstype
  pool=$(incus profile device get default root pool 2>/dev/null || true)
  [ -n "$pool" ] || pool="default"
  pool_source=$(incus storage show "$pool" 2>/dev/null | awk -F': ' '/^[[:space:]]*source:/{print $2; exit}')
  [ -n "$pool_source" ] && [ -e "$pool_source" ] || pool_source="/var/lib/incus/storage-pools/${pool}"

  if [ -e "$pool_source" ]; then
    fstype=$(stat -f -c %T "$pool_source" 2>/dev/null || echo "unknown")

    if [[ "$fstype" == *overlay* ]]; then
      echo "  [MISSING] The Incus storage pool '$pool' ($pool_source) sits on an OVERLAYFS backing filesystem."
      echo "            Docker's overlay2 driver does not support running overlay-on-overlay (official Docker limitation)."
      echo "            This cannot be fixed from inside the VPS. Fix on host: provision the Incus storage pool ('incus storage create')"
      echo "            on a disk/partition/loop file formatted with ext4, xfs (ftype=1), btrfs, or zfs instead."
      issues=$((issues+1))
    elif [[ "$fstype" == *xfs* ]]; then
      if command -v xfs_info >/dev/null 2>&1; then
        local ftype
        ftype=$(xfs_info "$pool_source" 2>/dev/null | grep -oE 'ftype=[01]' | cut -d= -f2)
        if [ "$ftype" = "0" ]; then
          echo "  [MISSING] The Incus storage pool '$pool' ($pool_source) is on XFS with ftype=0 (d_type disabled)."
          echo "            Docker's overlay2 driver refuses to run without d_type support (official Docker requirement)."
          echo "            This cannot be fixed from inside the VPS. Fix on host: reformat with 'mkfs.xfs -n ftype=1' and recreate the storage pool."
          issues=$((issues+1))
        fi
      else
        echo "  [WARNING] Storage pool '$pool' is on XFS but 'xfs_info' is not installed, so ftype=1 (d_type) support could not be verified."
        echo "            Install xfsprogs on the host and run: xfs_info $pool_source"
      fi
    fi
  fi

  if [ "$issues" -eq 0 ]; then
    echo "Host compatibility check passed. All prerequisites for Docker/containerd/WireGuard/etc. are in place."
  else
    echo "Host compatibility check found $issues issue(s) above. VPSForge will not attempt workarounds for host-level gaps;"
    echo "please apply the fixes shown above on the HOST, then re-run VPSForge."
  fi
}

save_iptables_rules() {
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
  else
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
  fi
}

port_forward_rule_exists() {
  local protocol="$1"
  local external_ip="$2"
  local external_port="$3"
  local internal_ip="$4"
  local internal_port="$5"
  local dest_spec=""
  [ -n "$external_ip" ] && dest_spec="-d $external_ip"

  iptables -t nat -C PREROUTING -p "$protocol" $dest_spec --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null
}

port_forward_rule_conflicts() {
  local protocol="$1"
  local external_ip="$2"
  local external_port="$3"
  local internal_ip="$4"
  local internal_port="$5"

  if iptables -t nat -S 2>/dev/null | grep -Eq "-p ${protocol}.*--dport ${external_port}.*DNAT --to-destination ${internal_ip}:${internal_port}"; then
    return 0
  fi
  return 1
}

port_forward_apply_rule() {
  local protocol="$1"
  local external_ip="$2"
  local external_port="$3"
  local internal_ip="$4"
  local internal_port="$5"
  local dest_spec=""
  [ -n "$external_ip" ] && dest_spec="-d $external_ip"

  if ! port_forward_rule_exists "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
    iptables -t nat -A PREROUTING -p "$protocol" $dest_spec --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port"
  fi

  iptables -C FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

  iptables -C FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" -m state --state ESTABLISHED,RELATED -j ACCEPT
}

port_forward_delete_rule() {
  local protocol="$1"
  local external_ip="$2"
  local external_port="$3"
  local internal_ip="$4"
  local internal_port="$5"
  local dest_spec=""
  [ -n "$external_ip" ] && dest_spec="-d $external_ip"

  iptables -t nat -C PREROUTING -p "$protocol" $dest_spec --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port" 2>/dev/null && \
    iptables -t nat -D PREROUTING -p "$protocol" $dest_spec --dport "$external_port" -j DNAT --to-destination "$internal_ip:$internal_port"

  iptables -D FORWARD -p "$protocol" -d "$internal_ip" --dport "$internal_port" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -p "$protocol" -s "$internal_ip" --sport "$internal_port" -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
}

port_forward_rule_file_exists() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] && [ -s "$file" ]
}

port_forward_rule_key() {
  printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5"
}

port_forward_append_rule_to_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  local protocol="$2"
  local external_ip="$3"
  local external_port="$4"
  local internal_ip="$5"
  local internal_port="$6"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  local key
  key=$(port_forward_rule_key "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port")
  if ! grep -Fxq "$key" "$file" 2>/dev/null; then
    printf '%s' "$key" >> "$file"
    printf '\n' >> "$file"
  fi
}

port_forward_remove_rule_from_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  local protocol="$2"
  local external_ip="$3"
  local external_port="$4"
  local internal_ip="$5"
  local internal_port="$6"
  local key
  [ -f "$file" ] || return 0
  key=$(port_forward_rule_key "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port")
  grep -Fvx "$key" "$file" 2>/dev/null > "${file}.tmp" || true
  mv "${file}.tmp" "$file"
}

port_forward_clear_rules_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  mkdir -p "$(dirname "$file")"
  : > "$file"
}

port_forward_save_rules_to_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  mkdir -p "$(dirname "$file")"
  cp "$PORT_FORWARD_RULES_FILE" "$file" 2>/dev/null || true
  if [ ! -f "$file" ]; then
    : > "$file"
  fi
}

port_forward_load_rules_from_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo "Rule file not found: $file"; return 1; }
  local protocol external_ip external_port internal_ip internal_port
  while IFS='|' read -r protocol external_ip external_port internal_ip internal_port; do
    [ -n "$protocol" ] || continue
    [ "$protocol" != "#" ] || continue
    [[ "$protocol" =~ ^(tcp|udp)$ ]] || continue
    if ! port_forward_rule_exists "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
      port_forward_apply_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
    fi
  done < "$file"
  save_iptables_rules
  echo "Loaded port-forward rules from $file"
}

port_forward_export_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  port_forward_save_rules_to_file "$file"
  echo "Exported rules to $file"
}

port_forward_import_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  port_forward_load_rules_from_file "$file"
}

port_forward_delete_all_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  if [ -f "$file" ]; then
    while IFS='|' read -r protocol external_ip external_port internal_ip internal_port; do
      [ -n "$protocol" ] || continue
      [ "$protocol" != "#" ] || continue
      [[ "$protocol" =~ ^(tcp|udp)$ ]] || continue
      port_forward_delete_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
    done < "$file"
  fi
  port_forward_clear_rules_file "$file"
  save_iptables_rules
  echo "Deleted all stored port-forward rules"
}

port_forward_disable_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  if [ -f "$file" ]; then
    while IFS='|' read -r protocol external_ip external_port internal_ip internal_port; do
      [ -n "$protocol" ] || continue
      [ "$protocol" != "#" ] || continue
      [[ "$protocol" =~ ^(tcp|udp)$ ]] || continue
      port_forward_delete_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
    done < "$file"
  fi
  save_iptables_rules
  echo "Disabled active port-forward rules"
}

port_forward_enable_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  port_forward_load_rules_from_file "$file"
}

port_forward_list_rules() {
  echo "Configured port-forward rules:"
  if [ -f "$PORT_FORWARD_RULES_FILE" ] && [ -s "$PORT_FORWARD_RULES_FILE" ]; then
    awk -F'|' 'NF {printf "- %s %s:%s -> %s:%s\n", $1, $2, $3, $4, $5}' "$PORT_FORWARD_RULES_FILE"
  else
    echo "No saved port-forward rules found."
  fi
}

port_forward_status() {
  echo "Active NAT port-forward rules:"
  iptables -t nat -S 2>/dev/null | grep -E 'DNAT --to-destination' || echo "No active DNAT port-forward rules found."
}

port_forward_cli() {
  local action="${1:-}"
  local protocol external_ip external_port internal_ip internal_port
  local target_file="${PORT_FORWARD_RULES_FILE}"

  case "$action" in
    add)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward add <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}"
      external_port="${4:-}"
      internal_ip="${5:-}"
      internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
      [[ "$external_port" =~ ^[0-9]+$ ]] || { echo "External port must be numeric."; return 1; }
      [[ "$internal_port" =~ ^[0-9]+$ ]] || { echo "Internal port must be numeric."; return 1; }
      if port_forward_rule_conflicts "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
        echo "Rule already exists for $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
        return 0
      fi
      if [ "$protocol" = "both" ]; then
        port_forward_apply_rule tcp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" tcp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_apply_rule udp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" udp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      else
        port_forward_apply_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      fi
      save_iptables_rules
      echo "Port forward applied: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;
    edit)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward edit <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}"
      external_port="${4:-}"
      internal_ip="${5:-}"
      internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
      [[ "$external_port" =~ ^[0-9]+$ ]] || { echo "External port must be numeric."; return 1; }
      [[ "$internal_port" =~ ^[0-9]+$ ]] || { echo "Internal port must be numeric."; return 1; }
      if [ "$protocol" = "both" ]; then
        port_forward_delete_rule tcp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" tcp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_delete_rule udp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" udp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      else
        port_forward_delete_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      fi
      if [ "$protocol" = "both" ]; then
        port_forward_apply_rule tcp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" tcp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_apply_rule udp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" udp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      else
        port_forward_apply_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      fi
      save_iptables_rules
      echo "Port forward updated: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;
    delete)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward delete <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}"
      external_port="${4:-}"
      internal_ip="${5:-}"
      internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
      if [ "$protocol" = "both" ]; then
        port_forward_delete_rule tcp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" tcp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_delete_rule udp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" udp "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      else
        port_forward_delete_rule "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      fi
      save_iptables_rules
      echo "Port forward removed: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;
    save)
      port_forward_save_rules_to_file "${2:-$target_file}"
      ;;
    export)
      port_forward_export_rules "${2:-$target_file}"
      ;;
    load)
      port_forward_load_rules_from_file "${2:-$target_file}"
      ;;
    import)
      port_forward_import_rules "${2:-$target_file}"
      ;;
    delete-all)
      port_forward_delete_all_rules "${2:-$target_file}"
      ;;
    disable)
      port_forward_disable_rules "${2:-$target_file}"
      ;;
    enable)
      port_forward_enable_rules "${2:-$target_file}"
      ;;
    status)
      port_forward_status
      ;;
    list)
      port_forward_list_rules
      ;;
    *)
      echo "Usage: vpsforge port-forward add|edit|delete|save|load|export|import|delete-all|enable|disable|list|status [args]"
      return 1
      ;;
  esac
}

get_network_info() {
  INCUS_CIDR=$(incus network get incusbr0 ipv4.address 2>/dev/null || true)
  [ -n "$INCUS_CIDR" ] && [ "$INCUS_CIDR" != "none" ] || { echo "incusbr0 has no IPv4."; exit 1; }
  INCUS_GATEWAY="${INCUS_CIDR%/*}"
  INCUS_NETMASK="${INCUS_CIDR#*/}"
  IFS='.' read -r A B C D <<< "$INCUS_GATEWAY"
  NETWORK_PREFIX="$A.$B.$C"
}

get_public_ip(){ PUBLIC_IP=$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo Unknown); }
get_num(){ echo "$1" | sed "s/^${VPS_PREFIX}//"; }
get_state(){ incus list "$1" -c s --format csv 2>/dev/null | head -1; }
get_ram(){ local r; r=$(incus config get "$1" limits.memory 2>/dev/null || true); echo "${r:-Unlimited}"; }

get_ip(){
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

get_port() {
  local ip="$1"; [ -z "$ip" ] && return
  iptables -t nat -L PREROUTING -n 2>/dev/null | awk -v ip="$ip" '$0 ~ "to:" ip ":22" {for(i=1;i<=NF;i++) if($i~/^dpt:/){sub(/^dpt:/,"",$i);print $i;exit}}'
}

remove_port() {
  local port="$1" line
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null | awk -v p="$port" '$0 ~ "dpt:" p {print $1;exit}')
    [ -z "$line" ] && break
    iptables -t nat -D PREROUTING "$line"
  done
}

remove_ip() {
  local ip="$1" line; [ -z "$ip" ] && return
  while :; do
    line=$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null | awk -v ip="$ip" '$0 ~ "to:" ip ":22" {print $1;exit}')
    [ -z "$line" ] && break
    iptables -t nat -D PREROUTING "$line"
  done
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
    done < <(incus list -c n --format csv | grep -E "^${VPS_PREFIX}[0-9]+$" || true)

    if [ "$found" -eq 0 ]; then
      echo "Removing stale rule: port $port -> $ip:22"
      remove_port "$port"
      removed=$((removed+1))
    fi
  done < <(iptables -t nat -L PREROUTING -n 2>/dev/null | grep -E "dpt:[0-9]+.*to:${NETWORK_PREFIX}\.[0-9]+:22" || true)

  save_fw
  echo "Cleanup complete. Removed $removed stale rule(s)."
}

save_fw(){ netfilter-persistent save >/dev/null 2>&1 || true; }

ram_mb() {
  case "$1" in
    *MiB) echo "${1%MiB}";;
    *GiB) echo $(( ${1%GiB} * 1024 ));;
    *MB) echo "${1%MB}";;
    *GB) echo $(( ${1%GB} * 1000 ));;
    Unlimited|"") echo 0;;
    *) echo "$1";;
  esac
}

total_allocated() {
  local t=0 n r
  while read -r n; do
    [ -z "$n" ] && continue
    r=$(ram_mb "$(get_ram "$n")")
    [[ "$r" =~ ^[0-9]+$ ]] && t=$((t+r))
  done < <(incus list -c n --format csv | grep -E "^${VPS_PREFIX}[0-9]+$" || true)
  echo "$t"
}

free_port() {
  local p=$((SSH_PORT_BASE + 1))
  while iptables -t nat -L PREROUTING -n 2>/dev/null | grep -qE "dpt:${p}([^0-9]|$)"; do p=$((p+1)); done
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

wait_ready(){ for _ in $(seq 1 60); do incus exec "$1" -- true >/dev/null 2>&1 && return 0; sleep 2; done; return 1; }

wait_guest_eth0() {
  local name="$1"

  for _ in $(seq 1 30); do
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
      netplan generate
    '; then
      # A minimal Incus guest may not expose udev/systemd services needed by
      # netplan. The direct ip setup below is still enough for this boot.
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
    # Ubuntu images often point resolv.conf at the local systemd-resolved stub.
    # Replace the link so DNS works even when that service is not running.
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
  local name="$1"
  local ip="${2:-}"

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
    if [ -r /etc/resolv.conf ]; then
      cat /etc/resolv.conf
    else
      echo "    missing /etc/resolv.conf"
    fi
  '

  if [ -n "$ip" ]; then
    echo "  expected IPv4: $ip"
  fi
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


apply_incus_compatibility_profile() {
  local name="$1"
  local raw_lxc

  # Apply the compatibility profile in a best-effort way.
  # Some Incus versions reject specific raw.lxc or syscall-intercept keys,
  # and those failures should not block container creation.
  incus config set "$name" security.nesting true >/dev/null 2>&1 || true
  incus config set "$name" security.privileged true >/dev/null 2>&1 || true
  incus config set "$name" security.syscalls.intercept.mknod true >/dev/null 2>&1 || true
  incus config set "$name" security.syscalls.intercept.setxattr true >/dev/null 2>&1 || true
  incus config set "$name" linux.kernel_modules "overlay,br_netfilter,nf_nat,ip_tables,iptable_nat,iptable_filter,bridge,veth,fuse,tun" >/dev/null 2>&1 || true

  raw_lxc=$(cat <<'EOF'
lxc.apparmor.profile=unconfined
lxc.cap.drop=
EOF
)
  if ! incus config set "$name" raw.lxc "$raw_lxc" >/dev/null 2>&1; then
    echo "WARNING: Incus rejected the optional raw.lxc compatibility settings for $name; continuing without them." >&2
  fi

  return 0
}

configure_vps_network_device() {
  local name="$1"

  ensure_device_override "$name" eth0 || return 1
  incus config device unset "$name" eth0 ipv4.address >/dev/null 2>&1 || true
  incus config device unset "$name" eth0 ipv4.gateway >/dev/null 2>&1 || true
  incus config device set "$name" eth0 name eth0 || true
  incus config device set "$name" eth0 network incusbr0 || true
}

create_vps() {
  local name="$1" num="$2" ram="$3" port="$4" ram_mode="${5:-limited}" cpu_mode="${6:-unlimited}" cpu_value="${7:-}" disk_mode="${8:-unlimited}" disk_value="${9:-}" network_mode="${10:-unlimited}" network_value="${11:-}"
  local ip="${NETWORK_PREFIX}.$((IP_START+num-1))"
  port=$(vps_fixed_port "$num")
  check_fixed_port_available "$name" "$ip" "$port" || return 1

  local ram_label cpu_label
  [ "$ram_mode" = "unlimited" ] && ram_label="Unlimited" || ram_label="${ram}MB"
  [ "$cpu_mode" = "unlimited" ] && cpu_label="$(get_host_cpu_count) Core(s)" || cpu_label="${cpu_value} Core(s)"
  echo "Creating $name | RAM $ram_label | CPU $cpu_label | IP $ip | Port $port"

  incus launch "$VPS_IMAGE" "$name" || return 1

  apply_incus_compatibility_profile "$name" || {
    echo "ERROR: Failed to apply Incus compatibility profile for $name."
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  configure_vps_network_device "$name" || {
    echo "ERROR: Failed to configure network device for $name."
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  incus config set "$name" user.vpsforge.ip "$ip" || true

  if [ "$ram_mode" = "unlimited" ]; then
    set_ram_mode_for_vps "$name" unlimited || {
      incus delete "$name" --force >/dev/null 2>&1 || true
      return 1
    }
  else
    set_ram_mode_for_vps "$name" limited "$ram" || {
      incus delete "$name" --force >/dev/null 2>&1 || true
      return 1
    }
  fi

  if [ "$cpu_mode" = "limited" ]; then
    set_cpu_mode_for_vps "$name" limited "$cpu_value" || {
      incus delete "$name" --force >/dev/null 2>&1 || true
      return 1
    }
  else
    set_cpu_mode_for_vps "$name" unlimited || {
      incus delete "$name" --force >/dev/null 2>&1 || true
      return 1
    }
  fi

  if [ "$disk_mode" = "limited" ]; then
    set_disk_mode_for_vps "$name" limited "$disk_value" || {
      incus delete "$name" --force >/dev/null 2>&1 || true
      return 1
    }
  else
    set_disk_mode_for_vps "$name" unlimited || {
      incus delete "$name" --force >/dev/null 2>&1 || true
      return 1
    }
  fi

  if [ "$network_mode" = "limited" ]; then
    set_network_mode_for_vps "$name" limited "$network_value" || {
      incus delete "$name" --force >/dev/null 2>&1 || true
      return 1
    }
  else
    set_network_mode_for_vps "$name" unlimited || {
      incus delete "$name" --force >/dev/null 2>&1 || true
      return 1
    }
  fi

  incus restart "$name" || {
    echo "ERROR: Failed to restart $name."
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  # Reserve and persist the selected SSH port immediately.
  set_vps_saved_port "$name" "$port"

  wait_ready "$name" || {
    echo "$name failed to become ready. Reserved port: $port"
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  wait_guest_eth0 "$name" || {
    echo "ERROR: eth0 did not appear inside $name."
    diagnose_guest_network "$name" "$ip"
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  # Helpful for nested workloads like Docker.
  incus exec "$name" -- touch /.dockerenv 2>/dev/null || true

  echo "Applying guest network config in $name..."
  apply_guest_static_network "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || {
    echo "ERROR: Failed to apply guest network config for $name."
    diagnose_guest_network "$name" "$ip"
    echo "Deleting incomplete VPS..."
    remove_ip "$ip"
    remove_port "$port"
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  configure_guest_dns "$name" || {
    echo "ERROR: Failed to configure guest DNS for $name."
    diagnose_guest_network "$name" "$ip"
    echo "Deleting incomplete VPS..."
    remove_ip "$ip"
    remove_port "$port"
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  if ! guest_network_config_ok "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}"; then
    echo "ERROR: Guest network still looks incomplete after guest network setup."
    diagnose_guest_network "$name" "$ip"
    echo "Deleting incomplete VPS..."
    remove_ip "$ip"
    remove_port "$port"
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  fi

  echo "Installing and configuring SSH in $name..."
  local ssh_install_ok=0 attempt
  for attempt in 1 2 3; do
    if incus exec "$name" -- bash -c '
      set -e
      export DEBIAN_FRONTEND=noninteractive
      mkdir -p /etc/apt/apt.conf.d
      printf "Acquire::ForceIPv4 \"true\";\n" > /etc/apt/apt.conf.d/99force-ipv4
      apt-get -o Acquire::ForceIPv4=true update
      apt-get -o Acquire::ForceIPv4=true install -y openssh-server
    '; then
      ssh_install_ok=1
      break
    fi

    echo "SSH installation attempt $attempt/3 failed for $name. Retrying..."
    sleep 3
  done

  [ "$ssh_install_ok" -eq 1 ] || {
    echo "Failed to install openssh-server in $name after 3 attempts."
    echo "Deleting incomplete VPS..."
    remove_ip "$ip"
    remove_port "$port"
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  printf 'root:%s\n' "$ROOT_PASSWORD" | incus exec "$name" -- chpasswd

  incus exec "$name" -- bash -c '
    set -e
    mkdir -p /etc/ssh/sshd_config.d
    printf "PermitRootLogin yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/99-root-login.conf
    systemctl enable --now ssh
  ' || {
    echo "Failed to enable SSH in $name."
    echo "Deleting incomplete VPS..."
    remove_ip "$ip"
    remove_port "$port"
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  local ssh_ready=0
  for _ in $(seq 1 30); do
    if incus exec "$name" -- bash -c 'ss -lnt 2>/dev/null | grep -qE "[:.]22[[:space:]]"'; then
      ssh_ready=1
      break
    fi
    sleep 1
  done

  [ "$ssh_ready" -eq 1 ] || {
    echo "SSH verification failed in $name."
    echo "Deleting incomplete VPS..."
    remove_ip "$ip"
    remove_port "$port"
    incus delete "$name" --force >/dev/null 2>&1 || true
    return 1
  }

  add_forward_rule "$ip" "$port"
  set_vps_user "$name" "root"
  set_vps_password "$name" "$ROOT_PASSWORD"
  set_vps_saved_port "$name" "$port"

  echo "Done: ssh root@$PUBLIC_IP -p $port"
}





get_host_cpu_count() {
  nproc
}

get_vps_ram_limit_mb() {
  local raw
  raw=$(incus config get "$1" limits.memory 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  ram_mb "$raw"
}

get_vps_ram_usage_mb() {
  local bytes
  bytes=$(incus query "/1.0/instances/$1/state" 2>/dev/null |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("memory",{}).get("usage",0))' 2>/dev/null || echo 0)
  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  echo $((bytes / 1024 / 1024))
}

get_host_available_ram_mb() {
  awk '/MemAvailable/{printf "%d",$2/1024}' /proc/meminfo
}

format_ram_display() {
  local name="$1" used limit
  used=$(get_vps_ram_usage_mb "$name")
  limit=$(get_vps_ram_limit_mb "$name")
  if [ -n "$limit" ] && [ "$limit" -gt 0 ] 2>/dev/null; then
    echo "${used}MB / ${limit}MB"
  else
    echo "${used}MB / $(get_host_available_ram_mb)MB"
  fi
}

get_vps_cpu_limit() {
  local configured
  configured=$(incus config get "$1" limits.cpu 2>/dev/null || true)
  if [ -n "$configured" ]; then
    echo "$configured"
  else
    get_host_cpu_count
  fi
}

set_ram_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" actual
  case "$mode" in
    unlimited)
      incus config unset "$name" limits.memory 2>/dev/null || true
      actual=$(incus config get "$name" limits.memory 2>/dev/null || true)
      [ -z "$actual" ] || {
        echo "ERROR: Failed to remove RAM limit from $name."
        return 1
      }
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$MIN_RAM_MB" ] || {
        echo "ERROR: Invalid RAM limit: $value MB."
        return 1
      }
      incus config set "$name" limits.memory "${value}MiB" || return 1
      actual=$(incus config get "$name" limits.memory 2>/dev/null || true)
      [ "$(ram_mb "$actual")" = "$value" ] || {
        echo "ERROR: RAM verification failed for $name. Requested=${value}MB Actual=${actual:-none}"
        return 1
      }
      ;;
    *) return 1 ;;
  esac
}

set_cpu_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual
  max=$(get_host_cpu_count)
  case "$mode" in
    unlimited)
      incus config unset "$name" limits.cpu 2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ] || {
        echo "ERROR: CPU limit must be between 1 and $max."
        return 1
      }
      incus config set "$name" limits.cpu "$value" || return 1
      actual=$(incus config get "$name" limits.cpu 2>/dev/null || true)
      [ "$actual" = "$value" ] || {
        echo "ERROR: CPU verification failed for $name."
        return 1
      }
      ;;
    *) return 1 ;;
  esac
}

ask_ram_mode() {
  local c v
  echo "RAM Mode for $1:"
  echo "Total RAM: $(get_host_total_ram_mb)MB | Available: $(get_host_available_ram_mb)MB"
  echo "1) Unlimited"
  echo "2) Set RAM Limit"
  read -r -p "Choice: " c
  case "$c" in
    1) RAM_MODE_RESULT="unlimited"; RAM_VALUE_RESULT="";;
    2)
      while :; do
        read -r -p "RAM Limit in MB (minimum $MIN_RAM_MB): " v
        [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge "$MIN_RAM_MB" ] && break
        echo "Invalid RAM limit."
      done
      RAM_MODE_RESULT="limited"; RAM_VALUE_RESULT="$v"
      ;;
    *) echo "Invalid choice."; return 1;;
  esac
}

ask_cpu_mode() {
  local c v max
  max=$(get_host_cpu_count)
  echo "CPU Mode for $1:"
  echo "1) Unlimited (all $max core(s))"
  echo "2) Set CPU Limit"
  read -r -p "Choice: " c
  case "$c" in
    1) CPU_MODE_RESULT="unlimited"; CPU_VALUE_RESULT="";;
    2)
      while :; do
        read -r -p "CPU Cores (1-$max): " v
        [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le "$max" ] && break
        echo "ERROR: Server has only $max CPU core(s). Allowed range: 1-$max."
      done
      CPU_MODE_RESULT="limited"; CPU_VALUE_RESULT="$v"
      ;;
    *) echo "Invalid choice."; return 1;;
  esac
}


get_host_total_ram_mb() {
  awk '/MemTotal/{printf "%d",$2/1024}' /proc/meminfo
}

get_host_disk_total_gb() {
  df -BG --output=size / | tail -1 | tr -dc '0-9'
}

get_host_disk_available_gb() {
  df -BG --output=avail / | tail -1 | tr -dc '0-9'
}

get_vps_disk_limit_gb() {
  local raw
  raw=$(incus config device get "$1" root size 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  echo "$raw" | awk '
    /GiB$/ {gsub(/GiB/,""); printf "%d",$1; exit}
    /GB$/  {gsub(/GB/,"");  printf "%d",$1; exit}
    /MiB$/ {gsub(/MiB/,""); printf "%d",$1/1024; exit}'
}

get_vps_disk_usage_gb() {
  local bytes
  bytes=$(incus exec "$1" -- df -B1 --output=used / 2>/dev/null | tail -1 | tr -dc '0-9')
  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  awk -v b="$bytes" 'BEGIN {printf "%.1f", b/1073741824}'
}

format_disk_display() {
  local name="$1" used limit
  used=$(get_vps_disk_usage_gb "$name")
  limit=$(get_vps_disk_limit_gb "$name")
  if [ -n "$limit" ]; then
    echo "${used}GB / ${limit}GB"
  else
    echo "${used}GB / $(get_host_disk_available_gb)GB"
  fi
}


ensure_device_override() {
  local name="$1" device="$2"

  # If device already exists in the instance's local config, no action is needed.
  if incus config show "$name" 2>/dev/null | awk '
      /^devices:/ {in_devices=1; next}
      in_devices && /^[^ ]/ {in_devices=0}
      in_devices && $0 ~ "^  '"$device"':$" {found=1}
      END {exit !found}
    '; then
    return 0
  fi

  incus config device override "$name" "$device" || {
    echo "ERROR: Failed to override device $device for $name."
    return 1
  }
}


set_disk_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual
  max=$(get_host_disk_total_gb)

  ensure_device_override "$name" root || return 1

  case "$mode" in
    unlimited)
      incus config device unset "$name" root size 2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ] || {
        echo "ERROR: Disk limit must be between 1GB and ${max}GB."
        return 1
      }
      incus config device set "$name" root size "${value}GiB" || return 1
      actual=$(incus config device get "$name" root size 2>/dev/null || true)
      [ "$actual" = "${value}GiB" ] || {
        echo "ERROR: Disk verification failed for $name. Requested=${value}GiB Actual=${actual:-none}"
        return 1
      }
      ;;
    *) return 1;;
  esac
}

ask_disk_mode() {
  local c v total available
  total=$(get_host_disk_total_gb)
  available=$(get_host_disk_available_gb)
  echo "Disk Mode for $1:"
  echo "Total Disk: ${total}GB | Available: ${available}GB"
  echo "1) Unlimited"
  echo "2) Set Disk Limit"
  read -r -p "Choice: " c
  case "$c" in
    1) DISK_MODE_RESULT="unlimited"; DISK_VALUE_RESULT="";;
    2)
      while :; do
        read -r -p "Disk Limit in GB (1-${total}): " v
        [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le "$total" ] && break
        echo "Invalid disk limit."
      done
      DISK_MODE_RESULT="limited"; DISK_VALUE_RESULT="$v"
      ;;
    *) return 1;;
  esac
}

get_total_network_mbit() {
  local saved speed iface
  saved=$(cat /opt/vpsforge/network_speed_mbit 2>/dev/null || true)
  if [[ "$saved" =~ ^[0-9]+$ ]] && [ "$saved" -gt 0 ]; then echo "$saved"; return; fi
  iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || true)
  if [[ "$speed" =~ ^[0-9]+$ ]] && [ "$speed" -gt 0 ]; then echo "$speed"; else echo 1000; fi
}

get_vps_network_limit_mbit() {
  local raw
  raw=$(incus config device get "$1" eth0 limits.egress 2>/dev/null || true)
  [ -n "$raw" ] || return 0
  echo "$raw" | tr -dc '0-9'
}


set_network_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual_in actual_out
  max=$(get_total_network_mbit)

  ensure_device_override "$name" eth0 || return 1

  case "$mode" in
    unlimited)
      incus config device unset "$name" eth0 limits.ingress 2>/dev/null || true
      incus config device unset "$name" eth0 limits.egress 2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ] || {
        echo "ERROR: Network limit must be between 1 and $max Mbit."
        return 1
      }
      incus config device set "$name" eth0 limits.ingress "${value}Mbit" || return 1
      incus config device set "$name" eth0 limits.egress "${value}Mbit" || return 1

      actual_in=$(incus config device get "$name" eth0 limits.ingress 2>/dev/null || true)
      actual_out=$(incus config device get "$name" eth0 limits.egress 2>/dev/null || true)
      [ "$actual_in" = "${value}Mbit" ] && [ "$actual_out" = "${value}Mbit" ] || {
        echo "ERROR: Network verification failed for $name."
        return 1
      }
      ;;
    *) return 1;;
  esac
}

ask_network_mode() {
  local c v max
  max=$(get_total_network_mbit)
  echo "Network Mode for $1:"
  echo "Total Network Speed: ${max} Mbit"
  echo "1) Unlimited"
  echo "2) Set Speed Limit"
  read -r -p "Choice: " c
  case "$c" in
    1) NETWORK_MODE_RESULT="unlimited"; NETWORK_VALUE_RESULT="";;
    2)
      while :; do
        read -r -p "Network Limit in Mbit (1-${max}): " v
        [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le "$max" ] && break
        echo "Invalid network limit."
      done
      NETWORK_MODE_RESULT="limited"; NETWORK_VALUE_RESULT="$v"
      ;;
    *) return 1;;
  esac
}

get_vps_user() {
  local u
  u=$(incus config get "$1" user.vpsforge.username 2>/dev/null || true)
  echo "${u:-root}"
}

set_vps_user() {
  incus config set "$1" user.vpsforge.username "$2"
}

get_vps_password() {
  local p
  p=$(incus config get "$1" user.vpsforge.password 2>/dev/null || true)
  echo "${p:-$ROOT_PASSWORD}"
}

set_vps_password() {
  incus config set "$1" user.vpsforge.password "$2"
}

get_vps_saved_port() {
  incus config get "$1" user.vpsforge.ssh_port 2>/dev/null || true
}

set_vps_saved_port() {
  incus config set "$1" user.vpsforge.ssh_port "$2"
}

normalize_selection() {
  local raw="$1" token name
  SELECTED_VPS=()

  if [[ "${raw,,}" = "all" ]]; then
    mapfile -t SELECTED_VPS < <(incus list -c n --format csv | grep -E "^${VPS_PREFIX}[0-9]+$" | sort -V || true)
  else
    IFS=',' read -ra TOKENS <<< "$raw"
    for token in "${TOKENS[@]}"; do
      token="${token//[[:space:]]/}"
      [ -z "$token" ] && continue
      [[ "$token" =~ ^[0-9]+$ ]] && name="${VPS_PREFIX}${token}" || name="$token"
      [[ "$name" =~ ^${VPS_PREFIX}[0-9]+$ ]] || { echo "Invalid VPS: $token"; return 1; }
      incus info "$name" >/dev/null 2>&1 || { echo "Not found: $name"; return 1; }
      [[ " ${SELECTED_VPS[*]} " == *" $name "* ]] || SELECTED_VPS+=("$name")
    done
  fi

  [ "${#SELECTED_VPS[@]}" -gt 0 ] || { echo "No VPS selected."; return 1; }
}

ask_vps_selection() {
  local prompt="${1:-VPS name/number, comma-separated list, or All: }" raw
  read -r -p "$prompt" raw
  normalize_selection "$raw"
}


ask_vps_selection_enter_all() {
  local input
  read -r -p "VPS name/number, comma-separated list, or All [Enter = All]: " input
  [ -n "$input" ] || input="All"

  normalize_selection "$input" || return 1

  [ "${#SELECTED_VPS[@]}" -gt 0 ] || {
    echo "No VPS containers selected."
    return 1
  }
}

show_selection() {
  echo "Selected: ${SELECTED_VPS[*]}"
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

  for _ in $(seq 1 30); do
    incus exec "$name" -- bash -c 'ss -lnt 2>/dev/null | grep -qE "[:.]22[[:space:]]"' && return 0
    sleep 1
  done
  return 1
}

add_forward_rule() {
  local ip="$1" port="$2"
  remove_port "$port"
  remove_ip "$ip"
  iptables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "${ip}:22"
  iptables -C FORWARD -p tcp -d "$ip" --dport 22 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -p tcp -d "$ip" --dport 22 -j ACCEPT
  save_fw
}

repair_vps_connection() {
  local name="$1" preferred_port="${2:-}" ip port reachable=0
  [ "$(get_state "$name")" = "RUNNING" ] || incus start "$name"
  wait_ready "$name" || { echo "FAILED: $name did not become ready."; return 1; }

  # Non-destructively refresh the Incus/Docker compatibility profile on
  # already-existing VPS (no delete, no reinstall). This heals containers
  # created by older VPSForge versions with outdated or unnecessary config
  # keys, and applies the official /.dockerenv fix from the Incus FAQ.
  apply_incus_compatibility_profile "$name" || echo "WARNING: could not refresh compatibility profile for $name."
  incus restart "$name" || true
  wait_ready "$name" || { echo "FAILED: $name did not become ready after profile refresh."; return 1; }
  incus exec "$name" -- touch /.dockerenv 2>/dev/null || true

  ip=$(get_ip "$name")
  [ -n "$ip" ] || { echo "FAILED: No IPv4 for $name."; return 1; }

  port=$(vps_fixed_port "$(get_num "$name")")
  check_fixed_port_available "$name" "$ip" "$port" || return 1
  set_vps_saved_port "$name" "$port"

  ensure_ssh_ready "$name" || { echo "FAILED: SSH could not start in $name."; return 1; }

  for _ in $(seq 1 15); do
    timeout 2 bash -c "</dev/tcp/$ip/22" >/dev/null 2>&1 && { reachable=1; break; }
    sleep 1
  done
  [ "$reachable" -eq 1 ] || { echo "FAILED: Host cannot reach $ip:22."; return 1; }

  add_forward_rule "$ip" "$port"
  echo "OK: $name | $PUBLIC_IP:$port -> $ip:22"
}


repair_connection_menu() {
  local n num preferred saved_port ip ok=0 failed=0
  local -a repair_list

  mapfile -t repair_list < <(
    incus list -c n --format csv | grep -E "^${VPS_PREFIX}[0-9]+$" | sort -V || true
  )

  [ "${#repair_list[@]}" -gt 0 ] || {
    echo "No VPS containers found."
    return
  }

  echo "Repairing all VPS connections..."
  echo

  for n in "${repair_list[@]}"; do
    num=$(get_num "$n")
    ip=$(get_ip "$n")
    saved_port=$(get_vps_saved_port "$n")
    preferred=$(vps_fixed_port "$num")
    if ! check_fixed_port_available "$n" "$ip" "$preferred"; then
      echo "FAILED: $n requires fixed port $preferred."
      failed=$((failed+1))
      echo
      continue
    fi
    set_vps_saved_port "$n" "$preferred"

    if repair_vps_connection "$n" "$preferred" </dev/null; then
      set_vps_saved_port "$n" "$preferred"
      ok=$((ok+1))
    else
      failed=$((failed+1))
    fi
    echo
  done

  cleanup_stale_rules
  echo
  echo "Repair summary: Success=$ok | Failed=$failed"
}

bulk_state_action() {
  local action="$1" n
  ask_vps_selection || return
  show_selection
  for n in "${SELECTED_VPS[@]}"; do
    echo "$action $n..."
    incus "$action" "$n" || echo "FAILED: $n"
  done
}

bulk_delete_menu() {
  local n ip p
  ask_vps_selection || return
  show_selection
  read -r -p "Type DELETE to permanently delete selected VPS containers: " x
  [ "$x" = "DELETE" ] || { echo "Cancelled."; return; }

  for n in "${SELECTED_VPS[@]}"; do
    echo "Deleting $n..."
    ip=$(get_ip "$n"); p=$(get_port "$ip")
    remove_ip "$ip"; [ -n "$p" ] && remove_port "$p"
    incus delete "$n" --force >/dev/null 2>&1 || true
    if incus list -c n --format csv 2>/dev/null | grep -Fxq "$n"; then
      echo "WARNING: $n still appears in Incus after delete attempt."
    else
      echo "Deleted $n"
    fi
  done
  save_fw
}



bulk_reinstall_menu() {
  local n num ip port x
  local ram_limit ram_mode cpu_limit cpu_mode
  local disk_limit disk_mode network_limit network_mode
  local saved_user saved_password

  ask_vps_selection || return
  show_selection
  read -r -p "Type REINSTALL to erase and reinstall selected VPS containers: " x
  [ "$x" = "REINSTALL" ] || { echo "Cancelled."; return; }

  for n in "${SELECTED_VPS[@]}"; do
    num=$(get_num "$n")
    ip=$(get_ip "$n")
    port=$(vps_fixed_port "$num")

    ram_limit=$(get_vps_ram_limit_mb "$n")
    cpu_limit=$(incus config get "$n" limits.cpu 2>/dev/null || true)
    disk_limit=$(get_vps_disk_limit_gb "$n")
    network_limit=$(get_vps_network_limit_mbit "$n")

    if [ -n "$ram_limit" ]; then
      ram_mode="limited"
    else
      ram_mode="unlimited"
      ram_limit="$MIN_RAM_MB"
    fi

    if [ -n "$cpu_limit" ]; then
      cpu_mode="limited"
    else
      cpu_mode="unlimited"
    fi

    if [ -n "$disk_limit" ]; then
      disk_mode="limited"
    else
      disk_mode="unlimited"
    fi

    if [ -n "$network_limit" ]; then
      network_mode="limited"
    else
      network_mode="unlimited"
    fi

    saved_user=$(get_vps_user "$n")
    saved_password=$(get_vps_password "$n")

    echo "Preserving $n settings:"
    echo "  RAM: $ram_mode ${ram_limit:+${ram_limit}MB}"
    echo "  CPU: $cpu_mode ${cpu_limit:+${cpu_limit} core(s)}"
    echo "  Disk: $disk_mode ${disk_limit:+${disk_limit}GB}"
    echo "  Network: $network_mode ${network_limit:+${network_limit}Mbit}"
    echo "  Port: $port"

    remove_ip "$ip"
    remove_port "$port"
    incus delete "$n" --force || { echo "FAILED deleting $n"; continue; }

    if create_vps "$n" "$num" "$ram_limit" "$port" \
        "$ram_mode" "$cpu_mode" "$cpu_limit" \
        "$disk_mode" "$disk_limit" "$network_mode" "$network_limit"; then
      [ "$saved_user" = "root" ] || change_vps_username "$n" "$saved_user"
      change_vps_password "$n" "$saved_password"
      echo "Reinstall completed for $n with preserved resource settings."
    else
      echo "FAILED reinstalling $n"
    fi
  done
}

bulk_change_ram_menu() {
  local n mode same r
  ask_vps_selection || return
  show_selection

  if [ "${#SELECTED_VPS[@]}" -eq 1 ]; then
    mode=1
  else
    echo "1) Individual RAM for each selected VPS"
    echo "2) Same RAM for all selected VPS"
    read -r -p "Choice: " mode
  fi

  case "$mode" in
    1)
      for n in "${SELECTED_VPS[@]}"; do
        while :; do
          read -r -p "New RAM for $n in MB: " r
          [[ "$r" =~ ^[0-9]+$ ]] && [ "$r" -ge "$MIN_RAM_MB" ] && break
          echo "Minimum RAM is ${MIN_RAM_MB}MB."
        done
        incus config set "$n" limits.memory "${r}MiB"
      done
      ;;
    2)
      while :; do
        read -r -p "RAM for all selected VPS containers in MB: " same
        [[ "$same" =~ ^[0-9]+$ ]] && [ "$same" -ge "$MIN_RAM_MB" ] && break
        echo "Minimum RAM is ${MIN_RAM_MB}MB."
      done
      for n in "${SELECTED_VPS[@]}"; do incus config set "$n" limits.memory "${same}MiB"; done
      ;;
    *) echo "Invalid choice.";;
  esac
}


validate_port() {
  local port="$1" current_ip="${2:-}" existing_ip
  [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || return 1
  existing_ip=$(iptables -t nat -L PREROUTING -n 2>/dev/null | awk -v p="$port" '
    $0 ~ "dpt:" p "([^0-9]|$)" {
      if (match($0,/to:([0-9.]+):22/,m)) print m[1]
      exit
    }' 2>/dev/null || true)
  [ -z "$existing_ip" ] || [ "$existing_ip" = "$current_ip" ]
}

change_vps_username() {
  local name="$1" new_user="$2" old_user password
  old_user=$(get_vps_user "$name")
  password=$(get_vps_password "$name")

  [[ "$new_user" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "Invalid username: $new_user"; return 1; }

  incus exec "$name" -- bash -c "id '$new_user' >/dev/null 2>&1 || useradd -m -s /bin/bash '$new_user'"
  incus exec "$name" -- usermod -aG sudo "$new_user" 2>/dev/null || true
  printf '%s:%s\n' "$new_user" "$password" | incus exec "$name" -- chpasswd
  set_vps_user "$name" "$new_user"

  echo "Username changed for $name: $old_user -> $new_user"
}

change_vps_password() {
  local name="$1" password="$2" user
  user=$(get_vps_user "$name")
  printf '%s:%s\n' "$user" "$password" | incus exec "$name" -- chpasswd || return 1
  set_vps_password "$name" "$password"
  echo "Password changed for $name."
}

change_vps_port() {
  local name="$1" new_port="$2" ip old_port
  ip=$(get_ip "$name")
  old_port=$(get_port "$ip")
  validate_port "$new_port" "$ip" || { echo "Port $new_port is invalid or already in use."; return 1; }

  [ -n "$old_port" ] && remove_port "$old_port"
  add_forward_rule "$ip" "$new_port"
  set_vps_saved_port "$name" "$new_port"
  echo "SSH port changed for $name: ${old_port:--} -> $new_port"
}



edit_single_vps() {
  local name="$1" c port user pass
  while :; do
    echo
    echo "0) Back"
    echo "1) Change RAM"
    echo "2) Change CPU"
    echo "3) Change Disk"
    echo "4) Change Network Speed"
    echo "5) Change SSH Port"
    echo "6) Change Username"
    echo "7) Change Password"
    read -r -p "Choice: " c
    case "$c" in
      1) ask_ram_mode "$name" && set_ram_mode_for_vps "$name" "$RAM_MODE_RESULT" "$RAM_VALUE_RESULT";;
      2) ask_cpu_mode "$name" && set_cpu_mode_for_vps "$name" "$CPU_MODE_RESULT" "$CPU_VALUE_RESULT";;
      3) ask_disk_mode "$name" && set_disk_mode_for_vps "$name" "$DISK_MODE_RESULT" "$DISK_VALUE_RESULT";;
      4) ask_network_mode "$name" && set_network_mode_for_vps "$name" "$NETWORK_MODE_RESULT" "$NETWORK_VALUE_RESULT";;
      5) read -r -p "New SSH port: " port; change_vps_port "$name" "$port";;
      6) read -r -p "New username: " user; change_vps_username "$name" "$user";;
      7) read -r -s -p "New password: " pass; echo; [ -n "$pass" ] && change_vps_password "$name" "$pass";;
      0) return;;
    esac
  done
}


edit_multiple_vps() {
  local c mode n value
  while :; do
    echo
    echo "0) Back"
    echo "1) Change RAM"
    echo "2) Change CPU"
    echo "3) Change Disk"
    echo "4) Change Network Speed"
    echo "5) Change Username"
    echo "6) Change Password"
    read -r -p "Choice: " c
    case "$c" in
      1|2|3|4)
        echo "1) Configure each VPS individually"
        echo "2) Same setting for all selected VPS"
        read -r -p "Choice: " mode
        for n in "${SELECTED_VPS[@]}"; do
          if [ "$mode" = "2" ] && [ "$n" != "${SELECTED_VPS[0]}" ]; then
            :
          else
            case "$c" in
              1) ask_ram_mode "$n" || continue; sm="$RAM_MODE_RESULT"; sv="$RAM_VALUE_RESULT";;
              2) ask_cpu_mode "$n" || continue; sm="$CPU_MODE_RESULT"; sv="$CPU_VALUE_RESULT";;
              3) ask_disk_mode "$n" || continue; sm="$DISK_MODE_RESULT"; sv="$DISK_VALUE_RESULT";;
              4) ask_network_mode "$n" || continue; sm="$NETWORK_MODE_RESULT"; sv="$NETWORK_VALUE_RESULT";;
            esac
          fi
          case "$c" in
            1) set_ram_mode_for_vps "$n" "$sm" "$sv";;
            2) set_cpu_mode_for_vps "$n" "$sm" "$sv";;
            3) set_disk_mode_for_vps "$n" "$sm" "$sv";;
            4) set_network_mode_for_vps "$n" "$sm" "$sv";;
          esac
        done
        ;;
      5) read -r -p "New username for all: " value; for n in "${SELECTED_VPS[@]}"; do change_vps_username "$n" "$value"; done;;
      6) read -r -s -p "New password for all: " value; echo; for n in "${SELECTED_VPS[@]}"; do change_vps_password "$n" "$value"; done;;
      0) return;;
    esac
  done
}

edit_vps_menu() {
  ask_vps_selection || return
  if [ "${#SELECTED_VPS[@]}" -eq 1 ]; then
    edit_single_vps "${SELECTED_VPS[0]}"
  else
    edit_multiple_vps
  fi
}


details() {
  local name="$1"
  local status ram cpu disk network ip port username
  local ram_limit cpu_limit disk_limit network_limit

  incus info "$name" >/dev/null 2>&1 || {
    echo "ERROR: VPS '$name' does not exist."
    return 1
  }

  status=$(get_state "$name" 2>/dev/null || true)
  [ -n "$status" ] || status="-"

  ram=$(format_ram_display "$name" 2>/dev/null || true)
  [ -n "$ram" ] || ram="-"

  cpu=$(get_vps_cpu_limit "$name" 2>/dev/null || true)
  if [ -n "$cpu" ]; then
    cpu="${cpu} Core$([ "$cpu" = "1" ] || echo s)"
  else
    cpu="-"
  fi

  disk=$(format_disk_display "$name" 2>/dev/null || true)
  [ -n "$disk" ] || disk="-"

  network=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
  if [ -n "$network" ]; then
    network="${network}Mbit"
  else
    network=$(get_total_network_mbit 2>/dev/null || true)
    [ -n "$network" ] && network="${network}Mbit" || network="-"
  fi

  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || ip="-"

  if [ "$ip" != "-" ]; then
    port=$(get_port "$ip" 2>/dev/null || true)
  else
    port=""
  fi
  [ -n "$port" ] || port=$(get_vps_saved_port "$name" 2>/dev/null || true)
  [ -n "$port" ] || port="-"

  username=$(get_vps_user "$name" 2>/dev/null || true)
  [ -n "$username" ] || username="-"

  ram_limit=$(get_vps_ram_limit_mb "$name" 2>/dev/null || true)
  cpu_limit=$(incus config get "$name" limits.cpu 2>/dev/null || true)
  disk_limit=$(get_vps_disk_limit_gb "$name" 2>/dev/null || true)
  network_limit=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)

  echo "================================================"
  echo "                    VPS DETAILS"
  echo "================================================"
  echo "Name:          $name"
  echo "Status:        $status"
  echo "RAM:           $ram"
  echo "RAM Mode:      $([ -n "$ram_limit" ] && echo "Limited (${ram_limit}MB)" || echo "Unlimited")"
  echo "CPU:           $cpu"
  echo "CPU Mode:      $([ -n "$cpu_limit" ] && echo "Limited (${cpu_limit} core(s))" || echo "Unlimited")"
  echo "Disk:          $disk"
  echo "Disk Mode:     $([ -n "$disk_limit" ] && echo "Limited (${disk_limit}GB)" || echo "Unlimited")"
  echo "Network:       $network"
  echo "Network Mode:  $([ -n "$network_limit" ] && echo "Limited (${network_limit}Mbit)" || echo "Unlimited")"
  echo "Internal IP:   $ip"
  echo "SSH Port:      $port"
  echo "Username:      $username"
  if [ "$port" != "-" ]; then
    echo "SSH Command:   ssh ${username}@${PUBLIC_IP} -p ${port}"
  fi
  echo "================================================"
}

bulk_details_menu() {
  local n
  ask_vps_selection_enter_all || return
  for n in "${SELECTED_VPS[@]}"; do
    echo
    details "$n"
  done
}

bulk_connection_menu() {
  local n ip p
  ask_vps_selection_enter_all || return
  for n in "${SELECTED_VPS[@]}"; do
    ip=$(get_ip "$n"); p=$(get_port "$ip")
    echo
    echo "================================================"
    echo "VPS Name:    $n"
    echo "Public IP:   $PUBLIC_IP"
    echo "Port:        ${p:--}"
    echo "Username:    $(get_vps_user "$n")"
    echo "Password:    $(get_vps_password "$n")"
    [ -n "$p" ] && echo "SSH Command: ssh $(get_vps_user "$n")@$PUBLIC_IP -p $p"
    echo "================================================"
  done
}

shell_menu() {
  ask_vps_selection "VPS name or number: " || return
  [ "${#SELECTED_VPS[@]}" -eq 1 ] || { echo "Shell supports one VPS at a time."; return; }
  incus exec "${SELECTED_VPS[0]}" -- bash
}



extract_version_from_text() {
  tr -d '\r' | grep -oE 'v[0-9]+(\.[0-9]+)*' | head -n1 || true
}

verify_installed_version() {
  local app="$1" target="$2" installed="" attempt

  # Prefer the program's own version output, but give it a few chances in case
  # the file was just replaced and the shell/container is still settling.
  for attempt in $(seq 1 10); do
    installed=$("$app" --version 2>/dev/null | extract_version_from_text)
    [ "$installed" = "$target" ] && return 0
    sleep 1
  done

  # Fallback: read the version constant directly from the installed file.
  installed=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$app" 2>/dev/null | head -n1)
  [ "$installed" = "$target" ]
}

update_menu() {
  local repo="/opt/vpsforge/repo"
  local app="/opt/vpsforge/vpsforge.sh"
  local choice target backup installed i
  local -a tags

  echo "Current version: $VPSFORGE_VERSION"
  [ -d "$repo/.git" ] || {
    echo "No Git repository configured."
    pause
    return
  }

  echo "Checking available versions..."
  git -C "$repo" fetch --tags --force || { echo "Failed to fetch versions."; pause; return; }
  mapfile -t tags < <(git -C "$repo" tag --sort=-version:refname)
  [ "${#tags[@]}" -gt 0 ] || { echo "No tagged versions found."; pause; return; }

  echo "Available versions:"
  for i in "${!tags[@]}"; do
    if [ "${tags[$i]}" = "$VPSFORGE_VERSION" ]; then
      echo "$((i+1))) ${tags[$i]} (current)"
    else
      echo "$((i+1))) ${tags[$i]}"
    fi
  done

  read -r -p "Choose version number, or press Enter to cancel: " choice
  [ -n "$choice" ] || return
  [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#tags[@]}" ] || {
    echo "Invalid choice."; pause; return
  }

  target="${tags[$((choice-1))]}"
  [ "$target" != "$VPSFORGE_VERSION" ] || { echo "Already running $target."; pause; return; }

  backup="/opt/vpsforge/vpsforge.sh.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$app" "$backup" || { echo "Failed to create backup."; pause; return; }

  echo "Switching: $VPSFORGE_VERSION -> $target"
  if ! git -C "$repo" show "${target}:vpsforge.sh" > "${app}.new"; then
    echo "Failed to read vpsforge.sh from tag $target."
    rm -f "${app}.new"
    pause
    return
  fi

  if grep -Eq '^VPSFORGE_VERSION=' "${app}.new"; then
    sed -i -E 's/^VPSFORGE_VERSION="v[0-9]+(\.[0-9]+)*"/VPSFORGE_VERSION="'"${target}"'"/' "${app}.new"
  fi

  chmod 755 "${app}.new"
  mv -f "${app}.new" "$app"

  if ! verify_installed_version "$app" "$target"; then
    installed=$("$app" --version 2>/dev/null | extract_version_from_text)
    [ -n "$installed" ] || installed=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$app" 2>/dev/null | head -n1)
    echo "Verification failed. Expected: $target | Installed: ${installed:-unknown}"
    echo "Restoring previous version..."
    cp "$backup" "$app"
    chmod 755 "$app"
    echo "Rollback completed."
    pause
    return 1
  fi

  installed=$target
  echo "Success: $VPSFORGE_VERSION -> $installed"
  sleep 1
  exec "$app"
}

list_vps() {
  printf "%-10s %-10s %-20s %-10s %-18s %-12s %-18s %-8s\n" NAME STATUS RAM CPU DISK NETWORK INTERNAL_IP PORT
  printf '%s\n' "----------------------------------------------------------------------------------------------------------------"

  local n s ram cpu disk net ip p
  local -a vps_list=()

  mapfile -t vps_list < <(
    incus list -c n --format csv 2>/dev/null |
    grep -E "^${VPS_PREFIX}[0-9]+$" |
    sort -V || true
  )

  for n in "${vps_list[@]}"; do
    [ -z "$n" ] && continue

    s=$(get_state "$n" 2>/dev/null || true)
    [ -n "$s" ] || s="-"

    ram=$(format_ram_display "$n" 2>/dev/null || true)
    [ -n "$ram" ] || ram="-"

    cpu=$(get_vps_cpu_limit "$n" 2>/dev/null || true)
    if [ -n "$cpu" ]; then
      cpu="${cpu} Core$([ "$cpu" = "1" ] || echo s)"
    else
      cpu="-"
    fi

    disk=$(format_disk_display "$n" 2>/dev/null || true)
    [ -n "$disk" ] || disk="-"

    net=$(get_vps_network_limit_mbit "$n" 2>/dev/null || true)
    if [ -n "$net" ]; then
      net="${net}Mbit"
    else
      net=$(get_total_network_mbit 2>/dev/null || true)
      [ -n "$net" ] && net="${net}Mbit" || net="-"
    fi

    ip=$(get_ip "$n" 2>/dev/null || true)
    [ -n "$ip" ] || ip="-"

    if [ "$ip" != "-" ]; then
      p=$(get_port "$ip" 2>/dev/null || true)
    else
      p=""
    fi
    [ -n "$p" ] || p="-"

    printf "%-10s %-10s %-20s %-10s %-18s %-12s %-18s %-8s\n" \
      "$n" "$s" "$ram" "$cpu" "$disk" "$net" "$ip" "$p"
  done
}

normalize_vps_input() {
  local value="$1"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "${VPS_PREFIX}${value}"
  else
    echo "$value"
  fi
}

select_vps() {
  read -r -p "VPS name or number: " SELECTED
  [[ "$SELECTED" =~ ^[0-9]+$ ]] && SELECTED="${VPS_PREFIX}${SELECTED}"
  incus info "$SELECTED" >/dev/null 2>&1 || { echo "Not found: $SELECTED"; return 1; }
}



next_num() {
  local highest=0 name num
  while IFS= read -r name; do
    [[ "$name" =~ ^${VPS_PREFIX}([0-9]+)$ ]] || continue
    num="${BASH_REMATCH[1]}"
    (( num > highest )) && highest="$num"
  done < <(incus list -c n --format csv 2>/dev/null || true)
  echo $((highest + 1))
}

add_menu() {
  local count i n name ip port setup effective_ram
  local -a names nums ports ram_modes ram_values cpu_modes cpu_values disk_modes disk_values network_modes network_values
  read -r -p "How many VPS containers do you want to add? " count
  [[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid count."; return; }
  if [ "$count" -gt 1 ]; then echo "1) Configure each VPS individually"; echo "2) Same resource settings for all"; read -r -p "Choice: " setup; else setup=1; fi
  if [ "$setup" = 2 ]; then
    ask_ram_mode "all new VPS containers" || return; shared_rm=$RAM_MODE_RESULT; shared_rv=$RAM_VALUE_RESULT
    ask_cpu_mode "all new VPS containers" || return; shared_cm=$CPU_MODE_RESULT; shared_cv=$CPU_VALUE_RESULT
    ask_disk_mode "all new VPS containers" || return; shared_dm=$DISK_MODE_RESULT; shared_dv=$DISK_VALUE_RESULT
    ask_network_mode "all new VPS containers" || return; shared_nm=$NETWORK_MODE_RESULT; shared_nv=$NETWORK_VALUE_RESULT
  fi
  local first_num
  first_num=$(next_num)
  for ((i=1;i<=count;i++)); do
    n=$((first_num + i - 1))
    name="${VPS_PREFIX}${n}"
    port=$(vps_fixed_port "$n")
    names+=("$name"); nums+=("$n"); ports+=("$port")
    if [ "$setup" = 2 ]; then
      ram_modes+=("$shared_rm"); ram_values+=("${shared_rv:-}"); cpu_modes+=("$shared_cm"); cpu_values+=("${shared_cv:-}")
      disk_modes+=("$shared_dm"); disk_values+=("${shared_dv:-}"); network_modes+=("$shared_nm"); network_values+=("${shared_nv:-}")
    else
      echo; echo "Resources for $name"
      ask_ram_mode "$name" || return; ram_modes+=("$RAM_MODE_RESULT"); ram_values+=("${RAM_VALUE_RESULT:-}")
      ask_cpu_mode "$name" || return; cpu_modes+=("$CPU_MODE_RESULT"); cpu_values+=("${CPU_VALUE_RESULT:-}")
      ask_disk_mode "$name" || return; disk_modes+=("$DISK_MODE_RESULT"); disk_values+=("${DISK_VALUE_RESULT:-}")
      ask_network_mode "$name" || return; network_modes+=("$NETWORK_MODE_RESULT"); network_values+=("${NETWORK_VALUE_RESULT:-}")
    fi
  done
  local ok=0 failed=0
  for i in "${!names[@]}"; do
    effective_ram="${ram_values[$i]:-$MIN_RAM_MB}"
    if create_vps "${names[$i]}" "${nums[$i]}" "$effective_ram" "${ports[$i]}" "${ram_modes[$i]}" "${cpu_modes[$i]}" "${cpu_values[$i]}" "${disk_modes[$i]}" "${disk_values[$i]}" "${network_modes[$i]}" "${network_values[$i]}"; then
      ok=$((ok+1))
    else
      echo "Creation failed for ${names[$i]}. Rolling back incomplete VPS..."
      remove_port "${ports[$i]}" 2>/dev/null || true
      incus delete "${names[$i]}" --force 2>/dev/null || true
      failed=$((failed+1))
    fi
  done
  echo "Creation summary: Success=$ok | Incomplete/Failed=$failed"
}

delete_menu() {
  select_vps || return
  local ip p; ip=$(get_ip "$SELECTED"); p=$(get_port "$ip")
  details "$SELECTED"
  read -r -p "Type DELETE to permanently delete: " x
  [ "$x" = DELETE ] || return
  remove_ip "$ip"; [ -n "$p" ] && remove_port "$p"
  incus delete "$SELECTED" --force && save_fw
}



reinstall_menu() {
  select_vps || return

  local num ip port x
  local ram_limit ram_mode cpu_limit cpu_mode
  local disk_limit disk_mode network_limit network_mode
  local saved_user saved_password

  num=$(get_num "$SELECTED")
  ip=$(get_ip "$SELECTED")
  port=$(vps_fixed_port "$num")

  ram_limit=$(get_vps_ram_limit_mb "$SELECTED")
  cpu_limit=$(incus config get "$SELECTED" limits.cpu 2>/dev/null || true)
  disk_limit=$(get_vps_disk_limit_gb "$SELECTED")
  network_limit=$(get_vps_network_limit_mbit "$SELECTED")

  if [ -n "$ram_limit" ]; then
    ram_mode="limited"
  else
    ram_mode="unlimited"
    ram_limit="$MIN_RAM_MB"
  fi

  if [ -n "$cpu_limit" ]; then
    cpu_mode="limited"
  else
    cpu_mode="unlimited"
  fi

  if [ -n "$disk_limit" ]; then
    disk_mode="limited"
  else
    disk_mode="unlimited"
  fi

  if [ -n "$network_limit" ]; then
    network_mode="limited"
  else
    network_mode="unlimited"
  fi

  saved_user=$(get_vps_user "$SELECTED")
  saved_password=$(get_vps_password "$SELECTED")

  details "$SELECTED"
  echo
  echo "Settings that will be preserved:"
  echo "  RAM: $ram_mode ${ram_limit:+${ram_limit}MB}"
  echo "  CPU: $cpu_mode ${cpu_limit:+${cpu_limit} core(s)}"
  echo "  Disk: $disk_mode ${disk_limit:+${disk_limit}GB}"
  echo "  Network: $network_mode ${network_limit:+${network_limit}Mbit}"
  echo "  Port: $port"

  read -r -p "Type REINSTALL to erase all data and reinstall: " x
  [ "$x" = "REINSTALL" ] || return

  remove_ip "$ip"
  remove_port "$port"
  incus delete "$SELECTED" --force || return 1

  create_vps "$SELECTED" "$num" "$ram_limit" "$port" \
    "$ram_mode" "$cpu_mode" "$cpu_limit" \
    "$disk_mode" "$disk_limit" "$network_mode" "$network_limit" || return 1

  [ "$saved_user" = "root" ] || change_vps_username "$SELECTED" "$saved_user"
  change_vps_password "$SELECTED" "$saved_password"

  echo "Reinstall completed with all resource settings preserved."
}

change_ram_menu() {
  select_vps || return
  read -r -p "New RAM limit in MB: " r
  [[ "$r" =~ ^[0-9]+$ ]] && [ "$r" -ge "$MIN_RAM_MB" ] || { echo Invalid; return; }
  incus config set "$SELECTED" limits.memory "${r}MiB"
}



SETTINGS_FILE="/opt/vpsforge/settings.conf"
AUTO_REFRESH="on"
REFRESH_INTERVAL=10

load_settings() {
  if [ -f "$SETTINGS_FILE" ]; then
    # shellcheck disable=SC1090
    source "$SETTINGS_FILE"
  fi
  [[ "$AUTO_REFRESH" = "on" || "$AUTO_REFRESH" = "off" ]] || AUTO_REFRESH="on"
  [[ "$REFRESH_INTERVAL" =~ ^[1-9][0-9]*$ ]] || REFRESH_INTERVAL=10
}

save_settings() {
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  {
    printf 'AUTO_REFRESH=%q\n' "$AUTO_REFRESH"
    printf 'REFRESH_INTERVAL=%q\n' "$REFRESH_INTERVAL"
  } > "$SETTINGS_FILE"
}

settings_menu() {
  local c new_interval
  while :; do
    clear
    echo "================================================"
    echo "                    SETTINGS"
    echo "================================================"
    echo
    echo "Auto Refresh: $([ "$AUTO_REFRESH" = "on" ] && echo ON || echo OFF)"
    echo "Refresh Interval: ${REFRESH_INTERVAL} seconds"
    echo "Current Version: $VPSFORGE_VERSION"
    echo
    echo "0) Back"
    echo "1) Enable / Disable Auto Refresh"
    echo "2) Change Refresh Interval"
    echo "3) Repair Connection"
    echo "4) Update / Change Version"
    echo
    read -r -p "Choice: " c

    case "$c" in
      1)
        if [ "$AUTO_REFRESH" = "on" ]; then AUTO_REFRESH="off"; else AUTO_REFRESH="on"; fi
        save_settings
        ;;
      2)
        read -r -p "New refresh interval in seconds: " new_interval
        [[ "$new_interval" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid interval."; pause; continue; }
        REFRESH_INTERVAL="$new_interval"
        save_settings
        ;;
      3)
        repair_connection_menu
        pause
        ;;
      4)
        update_menu
        ;;
      0) return;;
      *) sleep 1;;
    esac
  done
}

port_forward_menu() {
  local c protocol external_ip external_port internal_ip internal_port
  while :; do
    clear
    echo "================================================"
    echo "                  PORT FORWARD"
    echo "================================================"
    echo
    echo "1) Add Rule"
    echo "2) Edit Rule"
    echo "3) Delete Rule"
    echo "4) List Rules"
    echo "5) Status"
    echo "0) Back"
    echo
    read -r -p "Choice: " c

    case "$c" in
      1)
        read -r -p "Protocol [tcp/udp/both]: " protocol
        [ -n "$protocol" ] || protocol="tcp"
        read -r -p "External IP [0.0.0.0]: " external_ip
        [ -n "$external_ip" ] || external_ip="0.0.0.0"
        read -r -p "External Port: " external_port
        read -r -p "Internal IP: " internal_ip
        read -r -p "Internal Port: " internal_port
        port_forward_cli add "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        pause
        ;;
      2)
        read -r -p "Protocol [tcp/udp/both]: " protocol
        [ -n "$protocol" ] || protocol="tcp"
        read -r -p "External IP [0.0.0.0]: " external_ip
        [ -n "$external_ip" ] || external_ip="0.0.0.0"
        read -r -p "External Port: " external_port
        read -r -p "Internal IP: " internal_ip
        read -r -p "Internal Port: " internal_port
        port_forward_cli edit "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        pause
        ;;
      3)
        read -r -p "Protocol [tcp/udp/both]: " protocol
        [ -n "$protocol" ] || protocol="tcp"
        read -r -p "External IP [0.0.0.0]: " external_ip
        [ -n "$external_ip" ] || external_ip="0.0.0.0"
        read -r -p "External Port: " external_port
        read -r -p "Internal IP: " internal_ip
        read -r -p "Internal Port: " internal_port
        port_forward_cli delete "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        pause
        ;;
      4)
        port_forward_cli list
        pause
        ;;
      5)
        port_forward_cli status
        pause
        ;;
      0) return;;
      *) sleep 1;;
    esac
  done
}


dashboard() {
  clear
  local total allocated rem
  total=$(awk '/MemTotal/{printf "%d",$2/1024}' /proc/meminfo)
  allocated=$(total_allocated)
  rem=$((total-allocated))

  echo "================================================================"
  echo "                    VPSForge MANAGER $VPSFORGE_VERSION"
  echo "================================================================"
  echo "Auto Refresh: $([ "$AUTO_REFRESH" = "on" ] && echo "ON (${REFRESH_INTERVAL}s)" || echo "OFF")"
  echo "Public IP: $PUBLIC_IP | Total RAM: ${total}MB | VPS limits: ${allocated}MB | Remaining: ${rem}MB"
  echo
  list_vps
  echo
  echo "1) Add"
  echo "2) Delete"
  echo "3) Start"
  echo "4) Stop"
  echo "5) Restart"
  echo "6) Reinstall"
  echo "7) Edit VPS"
  echo "8) Details"
  echo "9) Shell"
  echo "10) Connection"
echo "11) Port Forward"
echo "12) Settings"
echo "13) Exit"
}

interactive() {
  local c
  load_settings
  while :; do
    dashboard
    c=""
    if [ "$AUTO_REFRESH" = "on" ]; then
      if ! read -r -t "$REFRESH_INTERVAL" -p "Choice: " c; then
        get_network_info
        get_public_ip
        continue
      fi
    else
      read -r -p "Choice: " c
    fi
    echo

    case "$c" in
      1) add_menu; pause;;
      2) bulk_delete_menu; pause;;
      3) bulk_state_action start; pause;;
      4) bulk_state_action stop; pause;;
      5) bulk_state_action restart; pause;;
      6) bulk_reinstall_menu; pause;;
      7) edit_vps_menu; pause;;
      8) bulk_details_menu; pause;;
      9) shell_menu;;
      10) bulk_connection_menu; pause;;
      11) port_forward_menu; pause;;
      12) settings_menu;;
      13) exit 0;;
      *) sleep 1;;
    esac
  done
}

ensure_setup
get_network_info
get_public_ip
load_settings

case "${1:-}" in
  "") interactive;;
  --version|-v|version) echo "VPSForge $VPSFORGE_VERSION";;
  list) list_vps;;
  details) incus info "${2:-}" >/dev/null 2>&1 && details "$2" || { echo "Usage: vpsforge details vps1"; exit 1; };;
  start|stop|restart) incus "$1" "${2:-}";;
  ram) [ -n "${2:-}" ] && [ -n "${3:-}" ] && incus config set "$2" limits.memory "${3}MiB" || echo "Usage: vpsforge ram vps1 1024";;
  repair|repair-all) repair_connection_menu;;
  port-forward|portforward) shift; port_forward_cli "$@";;
  *) echo "Usage: vpsforge [list|details vps1|start vps1|stop vps1|restart vps1|ram vps1 MB|repair-all|port-forward add|delete|list]";;
esac
