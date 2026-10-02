#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p outputs
touch outputs/.gdignore
game_engine="${SKYFIRE_GODOT:-$PWD/work/tools/Godot.app/Contents/MacOS/Godot}"
bash scripts/test.sh
"$game_engine" --headless --path "$PWD" --export-debug macOS 'outputs/Skyfire 1943 v0.9.app'
cp licenses/Godot-LICENSE.txt licenses/Godot-COPYRIGHT.txt 'outputs/Skyfire 1943 v0.9.app/Contents/Resources/'
codesign --force --sign - 'outputs/Skyfire 1943 v0.9.app'
codesign --verify --deep --strict 'outputs/Skyfire 1943 v0.9.app'
ditto -c -k --sequesterRsrc --keepParent 'outputs/Skyfire 1943 v0.9.app' outputs/skyfire-1943-v0.9-macos.zip
