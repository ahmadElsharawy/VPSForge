#!/bin/bash
get_vps_saved_port() { incus config get "$1" user.vpsforge.ssh_port 2>/dev/null || true; }
