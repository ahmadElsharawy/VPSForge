#!/bin/bash
# Static checks for VPSForge. Runs anywhere bash exists (Linux, macOS, Git Bash).
#   scripts/check.sh            -> syntax check (bash -n) on every script
#   scripts/check.sh --lint     -> also run shellcheck if installed
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

fail=0
mapfile -t files < <(find . -name '*.sh' -not -path './.git/*' | sort)

# Rule: one function per file (files with 2+ functions are rejected; applies to lib/ and scripts/lib/).
# Note: awk 'function x()' inside awk code is not a bash function and is not matched by the regex.
for f in "${files[@]}"; do
  case "$f" in ./lib/*|./scripts/lib/*) ;; *) continue;; esac
  case "$f" in */NIU/*) continue;; esac
  n=$(grep -cE '^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{' "$f" || true)
  if [ "${n:-0}" -gt 1 ]; then
    echo "FAIL: $f has $n functions (max 1 per file)"
    fail=1
  fi
done

# Rule: no duplicate functions across lib/ or within each scripts/lib/<script>/ folder.
declare -A seen_func=()
for f in "${files[@]}"; do
  case "$f" in */NIU/*) continue;; esac
  scope=""
  case "$f" in
    ./lib/*) scope="lib" ;;
    ./scripts/lib/*/*)
      sub="${f#./scripts/lib/}"
      scope="scripts/lib/${sub%%/*}"
      ;;
    ./scripts/lib/*) scope="scripts/lib" ;;
    *) continue ;;
  esac
  while read -r fn; do
    [ -n "$fn" ] || continue
    key="${scope}:${fn}"
    if [ -n "${seen_func[$key]:-}" ]; then
      echo "FAIL: duplicate function $fn in $f (already defined in ${seen_func[$key]})"
      fail=1
    else
      seen_func["$key"]="$f"
    fi
  done < <(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*()[[:space:]]*{.*/\1/p' "$f")
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

# A python that really runs (on Windows "python3" can be a Store shortcut that only fails).
PY=""
for c in python3 python; do "$c" -c 1 >/dev/null 2>&1 && { PY="$c"; break; }; done
if [ -n "$PY" ] && [ -f lib/dashboard/dashboard_helper.py ]; then
  "$PY" -B -c "import ast,sys; ast.parse(open(sys.argv[1], encoding='utf-8').read())" lib/dashboard/dashboard_helper.py || fail=1
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
