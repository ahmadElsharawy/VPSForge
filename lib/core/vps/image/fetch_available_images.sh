#!/bin/bash
# Build and cache the list of official Incus images available for a distribution.
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
    awk -v d="$distro" -v arch="$host_arch" '{
      alias = $0; gsub(/"/, "", alias); sub(/[[:space:]].*/, "", alias)
      n = split(alias, a, "/")
      if (a[1] == d && a[2] ~ /^[a-zA-Z0-9.-]+$/ && a[2] != "edge" && a[2] != "current") {
        if (n == 2) print "images:" alias
        else if (n == 3 && (a[3] == arch || a[3] ~ /^(amd64|arm64|armhf|i386|default)$/)) print "images:" a[1] "/" a[2]
      }
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
