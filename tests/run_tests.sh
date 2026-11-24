#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
export XDG_DATA_HOME="$TEST_ROOT/userdata"
"$GODOT_BIN" --headless --path . --editor --quit --log-file "$TEST_ROOT/import.log"
if rg -q 'SCRIPT ERROR|Parse Error|Failed to load' "$TEST_ROOT/import.log"; then exit 1; fi
for suite in test_sql_simulator test_campaign test_game_integration; do
    "$GODOT_BIN" --headless --path . --script "res://tests/$suite.gd" --log-file "$TEST_ROOT/$suite.log"
    if rg -q 'SCRIPT ERROR|ERROR:|FAIL|FALLOS:' "$TEST_ROOT/$suite.log"; then exit 1; fi
done
