#!/bin/bash
# Save a custom SSH port in the VPS container configuration.
set_vps_saved_port() {
  incus config set "$1" user.vpsforge.ssh_port "$2" 2>/dev/null || true
}
