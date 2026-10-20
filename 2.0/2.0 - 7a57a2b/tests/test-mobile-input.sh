#!/usr/bin/env bash
# The input accumulator has no OpenFL/Flixel dependencies. Isolate it from
# source/import.hx so this test only needs the project's Haxe compiler.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
cp "$project_dir/source/MobileControls.hx" "$test_dir/MobileControls.hx"
cp "$project_dir/tests/mobile-input/MobileInputTest.hx" "$test_dir/MobileInputTest.hx"
haxe -cp "$test_dir" -main MobileInputTest --interp
