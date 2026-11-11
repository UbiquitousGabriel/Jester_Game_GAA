#!/usr/bin/env bash
# Project validation: import, parse check, then the scripted smoke test.
# Usage: tools/validate.sh [path-to-godot-binary]
# Exits non-zero on the first failure. Requires Godot 4.7.x.
set -euo pipefail

GODOT="${1:-${GODOT:-godot}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== Godot version =="
"$GODOT" --version

echo "== Import (builds the class cache) =="
"$GODOT" --headless --path "$ROOT" --import

echo "== Compile every script =="
"$GODOT" --headless --path "$ROOT" res://tests/load_all.tscn

echo "== Smoke test (movement and combat) =="
"$GODOT" --headless --path "$ROOT" res://tests/smoke_test.tscn

echo "== World test (all rooms, doors, bosses, menus) =="
"$GODOT" --headless --path "$ROOT" res://tests/world_test.tscn

echo "All validation steps passed."
