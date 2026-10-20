#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
cp "$project_dir/source/GameplayRules.hx" "$test_dir/"
cp "$project_dir/tests/gameplay/GameplayRulesTest.hx" "$test_dir/"
haxe -cp "$test_dir" -main GameplayRulesTest --interp
