#!/bin/bash
# A VPN device name: letters, digits, dash or underscore, 1-32 characters (e.g. my-phone). Must start
# with a letter or digit: a leading dash would let the name pose as a command-line option (flag
# injection) when it reaches a backend tool.
is_valid_vpn_device_name() {
  [[ "${1:-}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,31}$ ]]
}
