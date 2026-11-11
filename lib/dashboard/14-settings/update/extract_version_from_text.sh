#!/bin/bash
# Extracts a semantic version string (e.g. v1.2.3) from standard input.
extract_version_from_text() {
  tr -d '\r' | grep -oE 'v[0-9]+(\.[0-9]+)*' | head -n1 || true
}
