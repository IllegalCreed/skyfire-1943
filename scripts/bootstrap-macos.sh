#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/tools/macos-template
mkdir -p outputs
touch work/.gdignore outputs/.gdignore
if [ ! -x work/tools/Godot.app/Contents/MacOS/Godot ]; then
  curl -fL --retry 2 'https://downloads.godotengine.org/?flavor=stable&platform=macos.universal&slug=macos.universal.zip&version=4.7.2' -o work/tools/godot-macos.zip
  ditto -x -k work/tools/godot-macos.zip work/tools
fi
if [ ! -f work/tools/macos-template/templates/macos.zip ]; then
  curl -fL --retry 2 'https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.7.2' -o work/tools/export_templates.tpz
  unzip -o work/tools/export_templates.tpz templates/macos.zip -d work/tools/macos-template
fi
work/tools/Godot.app/Contents/MacOS/Godot --version
