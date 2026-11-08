#!/bin/bash
# Build the list of images for <distro> from the official Incus image server
# (always current: nothing is hard-coded) and cache it for an hour.
#   fetch_available_images <distro> [force]      -> cache file: ${IMAGE_CACHE_PREFIX}<distro>.txt
fetch_available_images() {
  local distro="${1:-ubuntu}" force="${2:-false}"
  local cache="${IMAGE_CACHE_PREFIX}${distro}.txt" cache_ttl=3600
  local now mtime host_arch images

  if [ "$force" = "true" ]; then
    rm -f "$cache"
  elif [ -s "$cache" ]; then
    now=$(date +%s)
    mtime=$(stat -c %Y "$cache" 2>/dev/null || echo 0)
    [ $((now - mtime)) -lt "$cache_ttl" ] && return 0
  fi

  host_arch=$(get_host_arch)
  echo "Searching for official $distro releases for ($host_arch)..." >&2

  # One line per release (aliases like "debian/12"); skip cloud-init/other variants and "edge" builds.
  images=$(incus image list images: "$distro" type=container "architecture=${host_arch}" -c l --format csv 2>/dev/null |
    awk -v d="$distro" '{
      alias = $0; gsub(/"/, "", alias); sub(/[[:space:]].*/, "", alias)
      n = split(alias, a, "/")
      if (n == 2 && a[1] == d && a[2] ~ /^[a-zA-Z0-9.-]+$/ && a[2] != "edge" && a[2] != "current") print "images:" alias
    }' | sort -u -V -r)

  # Offline fallback so the menu is never empty.
  if [ -z "$images" ]; then
    case "$distro" in
      ubuntu) images=$(printf 'images:ubuntu/noble\nimages:ubuntu/jammy\n');;
      debian) images="images:debian/12";;
      *)      images="images:${distro}";;
    esac
  fi

  mkdir -p "$(dirname "$cache")"
  echo "$images" > "$cache"
}
