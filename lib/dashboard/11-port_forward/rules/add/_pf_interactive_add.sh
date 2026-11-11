#!/bin/bash
# Interactive "Add Port Forward Rule": 5 questions (0 = back one step), then conflict check, then add.
_pf_interactive_add() {
  echo
  echo "--- Add Port Forward Rule ---"
  PF_TARGET_VPS=""; PF_INTERNAL_IP=""; PF_EXT_PORT=""; PF_INT_PORT=""; PF_PROTOCOL="tcp"; PF_EXT_IP="0.0.0.0"

  run_wizard _pf_step_target _pf_step_ext_port _pf_step_int_port _pf_step_protocol _pf_step_bind_ip || {
    echo "Cancelled."
    return 1
  }

  _pf_resolve_rule_conflicts || return 1

  local host_status=0 go
  port_forward_host_conflict "$PF_EXT_PORT" "$PF_PROTOCOL" || host_status=$?
  if [ "$host_status" -eq 1 ]; then
    return 1
  elif [ "$host_status" -eq 2 ]; then
    read -r -p "Open the port anyway? [y/N]: " go </dev/tty
    [[ "${go,,}" =~ ^y ]] || { echo "Cancelled."; return 1; }
  fi

  echo
  port_forward_cli add "$PF_PROTOCOL" "$PF_EXT_IP" "$PF_EXT_PORT" "$PF_INTERNAL_IP" "$PF_INT_PORT"
}
