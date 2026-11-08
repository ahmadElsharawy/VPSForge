#!/bin/bash
# Static checks for VPSForge. Runs anywhere bash exists (Linux, macOS, Git Bash).
#   scripts/check.sh            -> syntax check (bash -n) on every script
#   scripts/check.sh --lint     -> also run shellcheck if installed
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

fail=0
mapfile -t files < <(find . -name '*.sh' -not -path './.git/*' | sort)

# Rule: one function per file (files with 2+ functions are rejected).
for f in "${files[@]}"; do
  case "$f" in ./lib/*) ;; *) continue;; esac
  n=$(grep -cE '^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{' "$f" || true)
  if [ "${n:-0}" -gt 1 ]; then
    echo "FAIL: $f has $n functions (max 1 per file)"
    fail=1
  fi
done

echo "Syntax check (bash -n) on ${#files[@]} files..."
for f in "${files[@]}"; do
  if ! bash -n "$f" 2>/tmp/vpsforge_check_err; then
    echo "FAIL: $f"
    sed 's/^/    /' /tmp/vpsforge_check_err
    fail=1
  fi
done
rm -f /tmp/vpsforge_check_err

if command -v python3 >/dev/null 2>&1 && [ -f lib/dashboard/dashboard_helper.py ]; then
  python3 -B -c "import ast,sys; ast.parse(open(sys.argv[1], encoding='utf-8').read())" lib/dashboard/dashboard_helper.py || fail=1
fi

if [ "${1:-}" = "--lint" ]; then
  if command -v shellcheck >/dev/null 2>&1; then
    echo "Running shellcheck (errors only)..."
    shellcheck -S error -x "${files[@]}" || fail=1
  else
    echo "shellcheck not installed; skipping lint."
  fi
fi

[ "$fail" -eq 0 ] && echo "All checks passed." || echo "Checks FAILED."
exit "$fail"
