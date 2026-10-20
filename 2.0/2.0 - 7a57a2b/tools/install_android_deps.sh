#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Isolate these versions from unrelated Haxe projects.
if [[ ! -d .haxelib ]]; then
  haxelib newrepo
fi
# Pin the legacy APIs used by this 2021 source snapshot. Do not run haxelib upgrade.
while read -r library version; do
  haxelib install "$library" "$version" --quiet --skip-dependencies
  haxelib set "$library" "$version"
done <<'LIBRARIES'
lime 7.9.0
openfl 9.2.2
flixel 4.9.0
flixel-addons 2.11.0
flixel-ui 2.5.0
hscript 2.4.0
actuate 1.9.0
newgrounds 1.1.5
hxcpp 4.2.1
formatter 1.13.0
LIBRARIES
