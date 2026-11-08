#!/bin/bash
get_vps_password() { incus config get "$1" user.vpsforge.password 2>/dev/null || echo "$ROOT_PASSWORD"; }
