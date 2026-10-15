#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
game_engine="${SKYFIRE_GODOT:-$PWD/work/tools/Godot.app/Contents/MacOS/Godot}"
mkdir -p work outputs
catalog_log="$PWD/work/catalog-capture.log"
"$game_engine" --path "$PWD" --quit-after 180 --log-file "$catalog_log" -- --capture-catalog
if rg -n 'SCRIPT ERROR|ERROR:|Assertion failed' "$catalog_log" || ! rg -q '^CATALOG PASS:' "$catalog_log"; then
  echo 'Catalog rendering failed.' >&2
  exit 1
fi
ruby scripts/build-unit-handbook.rb
