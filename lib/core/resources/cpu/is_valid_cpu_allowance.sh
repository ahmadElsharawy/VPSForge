#!/bin/bash
# Succeeds when <value> is a whole number between 1 and 100.
is_valid_cpu_allowance() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 100 ]
}
