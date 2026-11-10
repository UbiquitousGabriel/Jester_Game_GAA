#!/usr/bin/env bash
# Static GDScript syntax check with gdtoolkit (pip install gdtoolkit).
# This checks syntax only. It does not replace tools/validate.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
find "$ROOT/scripts" "$ROOT/tests" -name '*.gd' -print0 | xargs -0 gdparse
echo "gdparse: all scripts parsed."
