#!/bin/bash
# Runs the GUT test suite headless.
# Fails (exit 1) on failing tests, script/parse errors, or when no tests ran.
set -uo pipefail
cd "$(dirname "$0")/../game"
godot --headless --import >/dev/null 2>&1 || true
log="$(mktemp)"
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
  echo "run_tests: script errors detected" >&2; status=1
fi
if ! grep -qE "^Tests +[1-9]" "$log"; then
  echo "run_tests: no tests ran" >&2; status=1
fi
rm -f "$log"
exit $status
