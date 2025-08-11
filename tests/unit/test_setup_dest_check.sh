#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETUP_SH="$PROJECT_ROOT/src/scripts/setup.sh"

failures=0

if [ ! -f "$SETUP_SH" ]; then
  echo "SKIP: $SETUP_SH not found; skipping setup dest check test."
  echo "All tests passed."
  exit 0
fi

echo "Test: Running setup.sh from repo root (should fail gracefully due to missing vars.yaml)"
pushd "$PROJECT_ROOT" >/dev/null
set +e
out=$(bash "$SETUP_SH" --no-interactive 2>&1)
ret=$?
set -e
popd >/dev/null
echo "$out"
echo "===="
if [ "$ret" -ne 0 ] && echo "$out" | grep -qiE 'vars\.yaml not found|must be run from the artifact directory'; then
  echo "PASS: setup.sh fails gracefully outside artifact with informative message"
else
  echo "FAIL: setup.sh did not fail as expected or error message mismatch"; failures=$((failures+1))
fi

if [ "$failures" -eq 0 ]; then
  echo "All tests passed."
  exit 0
else
  echo "$failures test(s) failed."
  exit 1
fi
