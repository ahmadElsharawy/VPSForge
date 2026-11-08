#!/bin/bash
resolve_protocols() {
  case "$1" in
    both) echo "tcp udp";;
    *)    echo "$1";;
  esac
}
