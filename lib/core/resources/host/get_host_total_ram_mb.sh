#!/bin/bash
get_host_total_ram_mb()     { awk '/MemTotal/{printf "%d",$2/1024}' /proc/meminfo; }
