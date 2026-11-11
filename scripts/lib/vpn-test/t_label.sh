#!/bin/bash
# Check whether the device link includes the expected duration and quota label.
t_label() { vpn_device_link "$S" laptop | grep -q "#${PUBLIC_IP}-${S}-30d-50GB$"; }
