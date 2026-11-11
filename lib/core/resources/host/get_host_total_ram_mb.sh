#!/bin/bash
# Returns total RAM in MB on the host from /proc/meminfo.
get_host_total_ram_mb()     { awk '/MemTotal/{printf "%d",$2/1024}' /proc/meminfo; }
