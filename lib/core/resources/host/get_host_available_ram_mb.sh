#!/bin/bash
get_host_available_ram_mb() { awk '/MemAvailable/{printf "%d",$2/1024}' /proc/meminfo; }
