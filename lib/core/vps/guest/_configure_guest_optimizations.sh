#!/bin/bash
# Configure guest container hostname, remove stale dockerenv markers, and generate UTF-8 locale.
_configure_guest_optimizations() {
  local name="$1"
  set_guest_hostname "$name"
  incus exec "$name" -- sh -c '
    # Ensure no legacy or spurious Docker marker exists in native Incus/LXC system container
    rm -f /.dockerenv 2>/dev/null || true
    # Ensure locale is set to avoid warnings if possible
    if command -v locale-gen >/dev/null 2>&1; then
      locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
    fi
    if command -v update-locale >/dev/null 2>&1; then
      update-locale LANG=en_US.UTF-8 >/dev/null 2>&1 || true
    fi
  ' 2>/dev/null || true
}
