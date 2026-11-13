#!/bin/bash
# Download (once per host) the pinned crun and fuse-overlayfs static binaries for this CPU, checking
# their sha256, and print the folder that holds them. Returns 1 when they cannot be fetched.
#   ensure_docker_runtime_cache
ensure_docker_runtime_cache() {
  local crun_arch fo_arch crun_sum_var fo_sum_var entry file url sum tmp dir="$DOCKER_RT_CACHE_DIR"
  case "$(uname -m)" in
    aarch64|arm64) crun_arch=arm64; fo_arch=aarch64 ;;
    x86_64|amd64)  crun_arch=amd64; fo_arch=x86_64 ;;
    *) return 1 ;;
  esac
  crun_sum_var="CRUN_SHA256_${crun_arch}"
  fo_sum_var="FUSE_OVERLAYFS_SHA256_${fo_arch}"
  mkdir -p "$dir" || return 1

  for entry in \
    "crun|https://github.com/containers/crun/releases/download/${CRUN_VERSION}/crun-${CRUN_VERSION}-linux-${crun_arch}|${!crun_sum_var}" \
    "fuse-overlayfs|https://github.com/containers/fuse-overlayfs/releases/download/${FUSE_OVERLAYFS_VERSION}/fuse-overlayfs-${fo_arch}|${!fo_sum_var}"; do
    IFS='|' read -r file url sum <<< "$entry"
    # Already here and intact: nothing to download.
    if [ -s "$dir/$file" ] && echo "$sum  $dir/$file" | sha256sum -c --status 2>/dev/null; then
      continue
    fi
    tmp=$(mktemp "$dir/.download.XXXXXX") || return 1
    if ! curl -fsSL --max-time 120 -o "$tmp" "$url" || ! echo "$sum  $tmp" | sha256sum -c --status 2>/dev/null; then
      rm -f "$tmp"
      return 1
    fi
    chmod 755 "$tmp"
    mv -f "$tmp" "$dir/$file"
  done
  echo "$dir"
}
