#!/bin/bash
# Succeeds when <value> is between 1 and the number of CPU cores of this server.
is_valid_cpu_value() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le "$(get_host_cpu_count)" ]
}
