#!/bin/bash
# Interactive action: pick a VPN, then change the SNI of a protocol, make new keys, or restart it.
_vpn_action_edit_vpn() {
  local c kind sni answer
  vpn_pick_vpn || { pause; return; }
  while :; do
    echo
    echo "Edit the VPN on $VPN_VPS (port $(vpn_get_port "$VPN_VPS")):"
    echo "  SNI now:  Reality $(vpn_get_sni "$VPN_VPS") | TLS $(vpn_get_sni "$VPN_VPS" tls) | Hysteria2 $(vpn_get_sni "$VPN_VPS" hy)"
    echo "1) Change the Reality SNI"
    echo "2) Change the VLESS+TLS SNI"
    echo "3) Change the Hysteria2 SNI"
    echo "4) Reset keys              new keys; every device needs its new link (limits and usage stay)"
    echo "5) Restart the VPN         fixes a VPN that stopped answering; links stay the same"
    echo "6) Change the Hysteria2 UDP port   now $(vpn_get_hy_port "$VPN_VPS") (443, 2053, 2083, 2087, 2096, 4443, 8080... pass most networks)"
    echo "0) Back"
    read -r -p "Choice [0=Back]: " c </dev/tty
    case "$c" in
      1|2|3)
        case "$c" in 1) kind=reality;; 2) kind=tls;; 3) kind=hy;; esac
        read -r -p "New SNI [0=Back]: " sni </dev/tty
        [ -z "$sni" ] || [ "$sni" = "0" ] && continue
        vpn_set_sni "$VPN_VPS" "$kind" "$sni" && echo "DONE. Every device must import its links again (main VPN menu 3).";;
      4)
        echo "Which keys: 1) Reality  2) VLESS+TLS  3) Hysteria2  4) All three"
        read -r -p "Choice [0=Back]: " answer </dev/tty
        case "$answer" in 1) kind=reality;; 2) kind=tls;; 3) kind=hy;; 4) kind=all;; *) continue;; esac
        read -r -p "Old links of every device stop working. Continue? [y/N]: " answer </dev/tty
        [[ "${answer,,}" =~ ^y ]] || continue
        vpn_reset_keys "$VPN_VPS" "$kind" && echo "DONE. Send every device its new link (main VPN menu 3).";;
      5) vpn_guest_apply "$VPN_VPS" && echo "DONE. The VPN was restarted.";;
      6)
        read -r -p "New UDP port [0=Back]: " answer </dev/tty
        [ -z "$answer" ] || [ "$answer" = "0" ] && continue
        vpn_set_hy_port "$VPN_VPS" "$answer" && echo "Every device must import its links again (main VPN menu 3).";;
      0|"") return;;
      *) echo "Invalid choice.";;
    esac
  done
}
