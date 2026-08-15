get_host_arch() {
  local arch
  arch=$(uname -m 2>/dev/null || echo "x86_64")
  case "$arch" in
    x86_64|amd64)   echo "amd64" ;;
    aarch64|arm64)  echo "arm64" ;;
    armv7l|armhf)   echo "armhf" ;;
    *)              echo "$arch" ;;
  esac
}

normalize_image_alias() {
  local img="${1:-}"
  if [[ "$img" =~ ^images:ubuntu/([0-9]+\.[0-9]+)/minimal$ ]]; then
    echo "images:ubuntu/${BASH_REMATCH[1]}"
  else
    echo "$img"
  fi
}

resolve_image_candidates() {
  local raw="${1:-images:ubuntu/noble}"
  local -a list=()
  local clean="$raw"

  clean="${clean#images:}"
  clean="${clean#ubuntu:}"

  list+=("$raw")

  case "$clean" in
    24.04|ubuntu/24.04|noble|ubuntu/noble)
      list+=("images:ubuntu/noble" "images:ubuntu/24.04" "ubuntu:24.04" "ubuntu:noble" "images:ubuntu/noble/cloud")
      ;;
    22.04|ubuntu/22.04|jammy|ubuntu/jammy)
      list+=("images:ubuntu/jammy" "images:ubuntu/22.04" "ubuntu:22.04" "ubuntu:jammy" "images:ubuntu/jammy/cloud")
      ;;
    20.04|ubuntu/20.04|focal|ubuntu/focal)
      list+=("images:ubuntu/focal" "images:ubuntu/20.04" "ubuntu:20.04" "ubuntu:focal")
      ;;
    18.04|ubuntu/18.04|bionic|ubuntu/bionic)
      list+=("images:ubuntu/bionic" "images:ubuntu/18.04" "ubuntu:18.04" "ubuntu:bionic")
      ;;
    *)
      if [[ "$raw" != images:* ]] && [[ "$raw" != ubuntu:* ]]; then
        list+=("images:$raw" "ubuntu:$raw")
      fi
      ;;
  esac

  list+=("images:ubuntu/noble" "images:ubuntu/jammy" "images:ubuntu/24.04" "ubuntu:24.04" "ubuntu:noble")

  local -A seen=()
  local c
  for c in "${list[@]}"; do
    if [ -z "${seen[$c]:-}" ]; then
      seen[$c]=1
      echo "$c"
    fi
  done
}

image_exists() {
  local img="$1"
  [ -n "$img" ] || return 1
  if incus image info "$img" >/dev/null 2>&1; then
    return 0
  fi
  local c
  while read -r c; do
    [ -n "$c" ] || continue
    incus image info "$c" >/dev/null 2>&1 && return 0
  done < <(resolve_image_candidates "$img")
  return 1
}

fetch_available_ubuntu_images() {
  local force="${1:-false}"
  local cache_ttl=3600
  local now file_mtime age
  local host_arch
  host_arch=$(get_host_arch)

  if [ "$force" = "true" ]; then
    rm -f "$UBUNTU_IMAGES_CACHE_FILE"
  elif [ -f "$UBUNTU_IMAGES_CACHE_FILE" ]; then
    now=$(date +%s 2>/dev/null || echo 0)
    file_mtime=$(stat -c %Y "$UBUNTU_IMAGES_CACHE_FILE" 2>/dev/null || stat -f %m "$UBUNTU_IMAGES_CACHE_FILE" 2>/dev/null || echo 0)
    age=$((now - file_mtime))
    if [ "$age" -lt "$cache_ttl" ] && [ -s "$UBUNTU_IMAGES_CACHE_FILE" ]; then
      return 0
    fi
  fi

  echo "Searching for official Ubuntu releases for ($host_arch)..." >&2

  local dynamic_images
  dynamic_images=$(incus image list images: ubuntu type=container "architecture=${host_arch}" -c l --format csv 2>/dev/null |
    awk '{
      alias = $0;
      gsub(/"/, "", alias);
      if (alias ~ /^ubuntu\//) {
        sub(/[[:space:]].*/, "", alias);
        split(alias, a, "/");
        rel = a[2];
        if (rel ~ /^[a-zA-Z0-9.-]+$/) {
          if (alias ~ /\/cloud\// || alias ~ /\/cloud$/) {
            print "images:ubuntu/" rel "/cloud";
          } else {
            print "images:ubuntu/" rel;
          }
        }
      }
    }' | sort -u -V -r 2>/dev/null || true)

  if [ -z "$dynamic_images" ]; then
    dynamic_images=$(printf "images:ubuntu/noble\nimages:ubuntu/jammy\nimages:ubuntu/focal\nimages:ubuntu/noble/cloud\nimages:ubuntu/jammy/cloud\n")
  fi

  if [ -n "$dynamic_images" ]; then
    mkdir -p "$(dirname "$UBUNTU_IMAGES_CACHE_FILE")"
    echo "$dynamic_images" > "$UBUNTU_IMAGES_CACHE_FILE"
  fi
}
