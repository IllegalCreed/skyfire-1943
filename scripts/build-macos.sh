#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p outputs
test -x work/tools/Godot.app/Contents/MacOS/Godot || { echo 'Run bash scripts/bootstrap-macos.sh first'; exit 1; }
mkdir -p work
smoke_log="$PWD/work/build-smoke.log"
work/tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 8 --log-file "$smoke_log" -- --smoke
if rg -n 'SCRIPT ERROR|ERROR:|Assertion failed' "$smoke_log"; then
  echo 'Smoke checks failed; build stopped.'
  exit 1
fi
rg -q '^SMOKE PASS:' "$smoke_log" || { echo 'Smoke checks did not finish'; exit 1; }
work/tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug macOS 'outputs/Skyfire 1943 v0.2.app'
cp licenses/Godot-LICENSE.txt licenses/Godot-COPYRIGHT.txt 'outputs/Skyfire 1943 v0.2.app/Contents/Resources/'
codesign --force --sign - 'outputs/Skyfire 1943 v0.2.app'
codesign --verify --deep --strict 'outputs/Skyfire 1943 v0.2.app'
ditto -c -k --sequesterRsrc --keepParent 'outputs/Skyfire 1943 v0.2.app' outputs/skyfire-1943-v0.2-macos.zip
