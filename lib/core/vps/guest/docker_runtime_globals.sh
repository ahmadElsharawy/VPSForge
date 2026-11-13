#!/bin/bash
# Pinned static helpers that let Docker run inside an Isolated (unprivileged) VPS.
# Ubuntu's runc 1.3 cannot start containers there (it reopens /proc files the VPS may not touch);
# crun can. fuse-overlayfs replaces the kernel overlay mount an unprivileged VPS is not allowed.
# Each download is checked against its sha256 before it is used.
# shellcheck disable=SC2034
DOCKER_RT_CACHE_DIR="/opt/vpsforge/cache/docker-runtime"
CRUN_VERSION="1.19.1"
FUSE_OVERLAYFS_VERSION="v1.14"
CRUN_SHA256_arm64="4f28e8912fa52d1325cb42bfdc41d8f387d44e415955a82c203251e9dc1def5c"
CRUN_SHA256_amd64="eaa2408dee92432d142d58317127b5974d39a8ad48689ba8b2eff8f74614f4b8"
FUSE_OVERLAYFS_SHA256_aarch64="bf2c19b80e68afe1f53bae7a08cc9e7fb2f1b49bfdb9e5b49ab87cbe80b97cd1"
FUSE_OVERLAYFS_SHA256_x86_64="4817a8896a9e6f0433080f88f5b71dec931e8829a89d64c71af94b0630ccb4a9"
