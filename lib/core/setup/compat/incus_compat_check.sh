#!/bin/bash
# Quick self-test: do the Incus commands VPSForge depends on still behave as expected?
# Run it after ANY Incus update (vpsforge selftest). Creates and changes nothing.
# Prints one line per check and returns the number of failures.
incus_compat_check() {
  local failures=0 label
  local -a labels=() commands=()

  labels+=("Incus answers");                          commands+=("incus info")
  labels+=("list as JSON (dashboard)");               commands+=("incus list --format json | python3 -c 'import sys,json; json.load(sys.stdin)'")
  labels+=("list as CSV (names, states)");            commands+=("incus list -c ns --format csv")
  labels+=("REST API query (instance state)");        commands+=("incus query /1.0/instances")
  labels+=("storage pool info");                      commands+=("incus storage show default")
  labels+=("network settings (bridge)");              commands+=("incus network get incusbr0 ipv4.address")
  labels+=("profile device (root pool)");             commands+=("incus profile device get default root pool")
  labels+=("create: init + start flags");             commands+=("incus init --help | grep -q 'Usage'")
  labels+=("config device override/set");             commands+=("incus config device --help | grep -q override")
  labels+=("snapshot create/restore/delete");         commands+=("incus snapshot --help | grep -q restore")
  labels+=("export with compression");                commands+=("incus export --help | grep -q -- --compression")
  labels+=("import backup");                          commands+=("incus import --help | grep -q 'Usage'")
  labels+=("exec inside a VPS");                      commands+=("incus exec --help | grep -q -- --env")
  labels+=("remote image list columns");              commands+=("incus image list --help | grep -q -- --columns")

  local i
  for i in "${!labels[@]}"; do
    label="${labels[$i]}"
    if bash -c "${commands[$i]}" >/dev/null 2>&1; then
      printf '  PASS  %s\n' "$label"
    else
      printf '  FAIL  %s\n' "$label"
      failures=$((failures + 1))
    fi
  done
  echo "Incus $(incus --version 2>/dev/null): $((${#labels[@]} - failures)) of ${#labels[@]} checks passed."
  return "$failures"
}
