#!/bin/bash
# A VPN device name: letters, digits, dash or underscore, 1-32 characters (e.g. my-phone).
is_valid_vpn_device_name() {
  [[ "${1:-}" =~ ^[a-zA-Z0-9_-]{1,32}$ ]]
}
