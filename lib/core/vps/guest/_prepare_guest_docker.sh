#!/bin/bash
# Make Docker work in an Isolated VPS without making it privileged: copy crun and fuse-overlayfs into
# it and point Docker at them in /etc/docker/daemon.json (an existing file of the owner is kept).
# Docker itself is not installed here, so small servers stay light: however the owner installs
# Docker later, it picks this setup up. Never fails the VPS creation; it only warns.
#   _prepare_guest_docker <vps>
_prepare_guest_docker() {
  local name="${1:?vps}" dir
  dir=$(ensure_docker_runtime_cache) || {
    echo "WARNING: could not download the Docker helpers for $name (no internet?). Docker inside it will not start until they are added."
    return 0
  }
  if ! incus file push -p --mode 0755 "$dir/crun" "$name/usr/local/bin/crun" >/dev/null 2>&1 ||
     ! incus file push -p --mode 0755 "$dir/fuse-overlayfs" "$name/usr/local/bin/fuse-overlayfs" >/dev/null 2>&1; then
    echo "WARNING: could not copy the Docker helpers into $name."
    return 0
  fi
  incus exec "$name" -- sh -c '
    [ -s /etc/docker/daemon.json ] && exit 0
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "fuse-overlayfs",
  "runtimes": { "crun": { "path": "/usr/local/bin/crun" } },
  "default-runtime": "crun"
}
EOF
  ' >/dev/null 2>&1 || echo "WARNING: could not write /etc/docker/daemon.json in $name."
  return 0
}
