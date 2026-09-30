#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p outputs
test -x work/tools/Godot.app/Contents/MacOS/Godot || { echo 'Run bash scripts/bootstrap-macos.sh first'; exit 1; }
work/tools/Godot.app/Contents/MacOS/Godot --headless --path . -- --smoke
work/tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug macOS 'outputs/Skyfire 1943.app'
cp licenses/Godot-LICENSE.txt licenses/Godot-COPYRIGHT.txt 'outputs/Skyfire 1943.app/Contents/Resources/'
codesign --force --sign - 'outputs/Skyfire 1943.app'
codesign --verify --deep --strict 'outputs/Skyfire 1943.app'
ditto -c -k --sequesterRsrc --keepParent 'outputs/Skyfire 1943.app' outputs/skyfire-1943-macos.zip
