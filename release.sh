#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 vX.Y.Z"
  exit 1
fi
ver="$1"
repo_dir="$(cd "$(dirname "$0")" && pwd)"
file="$repo_dir/vpsforge.sh"

# Update version in file
if grep -q 'VPSFORGE_VERSION="' "$file"; then
  sed -i -E "s/^VPSFORGE_VERSION=\"v[0-9]+(\\.[0-9]+)*\"/VPSFORGE_VERSION=\"${ver}\"/" "$file"
else
  echo "VPSFORGE_VERSION not found in $file"
  exit 1
fi

cd "$repo_dir"

git add "$file"
git commit -m "Bump version to ${ver}" || true

git tag -a "$ver" -m "Release ${ver}" || true

echo "Pushing branch and tag to origin..."
git push origin HEAD

git push origin "$ver" || true

if command -v gh >/dev/null 2>&1; then
  gh release create "$ver" --title "$ver" --notes "Release $ver"
else
  echo "gh CLI not installed; create a Release on GitHub manually if desired."
fi

echo "Done."
