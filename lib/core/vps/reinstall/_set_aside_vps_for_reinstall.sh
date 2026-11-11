#!/bin/bash
# Move the original VPS to a temporary backup container name before reinstalling.
_set_aside_vps_for_reinstall() {
  local name="$1" old="$2"
  if incus info "$old" >/dev/null 2>&1 && [ "$(incus config get "$old" user.vpsforge.reinstall_of 2>/dev/null || true)" != "$name" ]; then
    echo "ERROR: a VPS named '$old' already exists and is not a leftover of this reinstall. Rename or delete it first. Nothing was changed."
    return 1
  fi
  incus delete "$old" --force >/dev/null 2>&1 || true
  incus stop "$name" --force >/dev/null 2>&1 || true
  if ! incus rename "$name" "$old"; then
    echo "ERROR: could not set the original VPS aside; nothing was changed."
    incus start "$name" >/dev/null 2>&1 || true
    return 1
  fi
  mark_vps_state "$old" reinstall-old
  incus config set "$old" user.vpsforge.reinstall_of "$name" >/dev/null 2>&1 || true
}
