#!/bin/bash
# Set up firewall rules to isolate VPS traffic and allow Internet routing.
setup_inter_vps_isolation() {
  # setup runs before the main script reads the network: read it here, never skip isolation silently
  [ -n "${NETWORK_PREFIX:-}" ] && [ -n "${INCUS_GATEWAY:-}" ] || get_network_info >/dev/null 2>&1 || true
  if [ -z "${NETWORK_PREFIX:-}" ]; then
    echo "WARNING: could not read the VPS network, so VPSs are NOT isolated from each other yet. Run 'vpsforge setup' again." >&2
    return 1
  fi
  local subnet="${NETWORK_PREFIX}.0/24"

  modprobe br_netfilter 2>/dev/null || true
  sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>&1 || true
  sysctl -w net.bridge.bridge-nf-call-ip6tables=1 >/dev/null 2>&1 || true

  # Block cloud metadata (IMDS) from every VPS. Without this a tenant with root in one VPS can read the
  # host's instance-principal certificate/key, SSH keys and tokens from 169.254.169.254 and take over the
  # owner's cloud account. The host itself still reaches it (that is OUTPUT traffic, not FORWARD).
  iptables -C FORWARD -i incusbr0 -d 169.254.169.254 -j DROP 2>/dev/null || \
    iptables -I FORWARD 1 -i incusbr0 -d 169.254.169.254 -j DROP
  if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -C FORWARD -i incusbr0 -d fd00:ec2::254 -j DROP 2>/dev/null || \
      ip6tables -I FORWARD 1 -i incusbr0 -d fd00:ec2::254 -j DROP 2>/dev/null || true
  fi

  iptables -t nat -C POSTROUTING -s "$subnet" ! -d "$subnet" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$subnet" ! -d "$subnet" -j MASQUERADE

  iptables -t nat -C POSTROUTING -s "$subnet" -d "$subnet" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$subnet" -d "$subnet" -j MASQUERADE

  iptables -C FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  iptables -C FORWARD -m conntrack --ctstate DNAT -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 2 -m conntrack --ctstate DNAT -j ACCEPT

  iptables -C FORWARD -i incusbr0 ! -o incusbr0 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 3 -i incusbr0 ! -o incusbr0 -j ACCEPT

  if [ -n "${INCUS_GATEWAY:-}" ]; then
    iptables -C FORWARD -i incusbr0 -s "$subnet" -d "$INCUS_GATEWAY" -j ACCEPT 2>/dev/null || \
      iptables -I FORWARD 4 -i incusbr0 -s "$subnet" -d "$INCUS_GATEWAY" -j ACCEPT
  fi

  iptables -C FORWARD -i incusbr0 -o incusbr0 -j DROP 2>/dev/null || \
    iptables -A FORWARD -i incusbr0 -o incusbr0 -j DROP

  iptables -C FORWARD -s "$subnet" -d "$subnet" -j DROP 2>/dev/null || \
    iptables -A FORWARD -s "$subnet" -d "$subnet" -j DROP

  # A VPS's network card has MTU 1420, but programs inside it (Docker's own network: 1500) can
  # announce bigger TCP segments; those big replies are lost and HTTPS hangs. Clamp every TCP
  # connection through the bridge to what fits in 1420 (1420 - 40 bytes of headers).
  local dir
  for dir in -i -o; do
    iptables -t mangle -C FORWARD "$dir" incusbr0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1380 2>/dev/null || \
      iptables -t mangle -A FORWARD "$dir" incusbr0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1380 2>/dev/null || true
  done

  if command -v ip6tables >/dev/null 2>&1; then   # the bridge may carry IPv6 too: no VPS-to-VPS traffic there either
    ip6tables -C FORWARD -i incusbr0 -o incusbr0 -j DROP 2>/dev/null || \
      ip6tables -I FORWARD 1 -i incusbr0 -o incusbr0 -j DROP 2>/dev/null || true
  fi

  # A VPS may reach the host only for DNS, DHCP and ICMP. Everything else the host listens on (its own
  # SSH, the Caddy proxy/admin, the VPN subscription server, rpcbind, ...) must be invisible to tenants,
  # so one tenant cannot probe host services or open another tenant's subscription page from the inside.
  iptables -C INPUT -i incusbr0 -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -i incusbr0 -p udp --dport 53 -j ACCEPT
  iptables -C INPUT -i incusbr0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT 2 -i incusbr0 -p tcp --dport 53 -j ACCEPT
  iptables -C INPUT -i incusbr0 -p udp --dport 67 -j ACCEPT 2>/dev/null || iptables -I INPUT 3 -i incusbr0 -p udp --dport 67 -j ACCEPT
  iptables -C INPUT -i incusbr0 -p icmp -j ACCEPT 2>/dev/null || iptables -I INPUT 4 -i incusbr0 -p icmp -j ACCEPT
  iptables -C INPUT -i incusbr0 -j DROP 2>/dev/null || iptables -A INPUT -i incusbr0 -j DROP
  if command -v ip6tables >/dev/null 2>&1; then
    # ICMPv6 must stay open or IPv6 (NDP) breaks; DNS/DHCPv6 too. Drop the rest to the host.
    ip6tables -C INPUT -i incusbr0 -p ipv6-icmp -j ACCEPT 2>/dev/null || ip6tables -I INPUT 1 -i incusbr0 -p ipv6-icmp -j ACCEPT 2>/dev/null || true
    ip6tables -C INPUT -i incusbr0 -p udp --dport 53 -j ACCEPT 2>/dev/null || ip6tables -I INPUT 2 -i incusbr0 -p udp --dport 53 -j ACCEPT 2>/dev/null || true
    ip6tables -C INPUT -i incusbr0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || ip6tables -I INPUT 3 -i incusbr0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
    ip6tables -C INPUT -i incusbr0 -p udp --dport 547 -j ACCEPT 2>/dev/null || ip6tables -I INPUT 4 -i incusbr0 -p udp --dport 547 -j ACCEPT 2>/dev/null || true
    ip6tables -C INPUT -i incusbr0 -j DROP 2>/dev/null || ip6tables -A INPUT -i incusbr0 -j DROP 2>/dev/null || true
  fi

  _purge_legacy_forward_rules "$NETWORK_PREFIX"

  purge_invalid_dnat_rules
  save_iptables

  # Re-apply per-VPS anti-spoofing + fork-bomb caps to every existing VPS, so upgrading an older install
  # protects the VPSs already running (one `incus list`, then a cheap idempotent config set each).
  local _vps
  while IFS= read -r _vps; do
    [ -n "$_vps" ] && harden_vps_security "$_vps"
  done < <(incus list -c n --format csv 2>/dev/null)
}
