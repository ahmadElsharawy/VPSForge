#!/bin/bash
# Splits a combined CPU value into CPU_CORES_PART and CPU_ALLOWANCE_PART.
split_cpu_value() {
  local val="${1:-}"
  if [[ "$val" == *"@"* ]]; then
    CPU_CORES_PART="${val%%@*}"
    CPU_ALLOWANCE_PART="${val#*@}"
  else
    CPU_CORES_PART="$val"
    CPU_ALLOWANCE_PART=""
  fi
}
