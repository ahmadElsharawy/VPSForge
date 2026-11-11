#!/bin/bash
# Check whether listening port 8088 is detected inside the test container.
app_listed() { list_vps_listening_ports "$T" | grep -qx 8088; }
