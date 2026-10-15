#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p outputs
touch outputs/.gdignore
game_engine="${SKYFIRE_GODOT:-$PWD/work/tools/Godot.app/Contents/MacOS/Godot}"
bash scripts/test.sh
for edition in player developer; do
  if [ "$edition" = player ]; then
    preset='macOS'
    export_kind='--export-debug'
    app_path='outputs/Skyfire 1943 v0.16.app'
    zip_path='outputs/skyfire-1943-v0.16-macos.zip'
    build_arg='--expect-player'
  else
    preset='macOS Developer'
    export_kind='--export-debug'
    app_path='outputs/Skyfire 1943 v0.16 Developer.app'
    zip_path='outputs/skyfire-1943-v0.16-developer-macos.zip'
    build_arg='--expect-developer'
  fi
  export_log="$PWD/work/export-$edition.log"
  "$game_engine" --headless --path "$PWD" --log-file "$export_log" "$export_kind" "$preset" "$app_path"
  if rg -n 'SCRIPT ERROR|ERROR:|Assertion failed' "$export_log"; then
    echo "Export failed: $edition" >&2
    exit 1
  fi
  cp licenses/Godot-LICENSE.txt licenses/Godot-COPYRIGHT.txt "$app_path/Contents/Resources/"
  codesign --force --sign - "$app_path"
  codesign --verify --deep --strict "$app_path"
  app_binary="$app_path/Contents/MacOS/Skyfire 1943"
  smoke_log="$PWD/work/app-$edition-smoke.log"
  "$app_binary" --headless --quit-after 8 --log-file "$smoke_log" -- --smoke
  if rg -n 'SCRIPT ERROR|ERROR:|Assertion failed' "$smoke_log" || ! rg -q '^SMOKE PASS:' "$smoke_log"; then
    echo "Exported app smoke failed: $edition" >&2
    exit 1
  fi
  ui_log="$PWD/work/app-$edition-ui.log"
  "$app_binary" --headless --quit-after 180 --log-file "$ui_log" -- --check-build "$build_arg"
  if rg -n 'SCRIPT ERROR|ERROR:|Assertion failed' "$ui_log" || ! rg -q '^BUILD PASS:' "$ui_log"; then
    echo "Exported app menu check failed: $edition" >&2
    exit 1
  fi
  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
  unzip -tq "$zip_path"
done
bash scripts/build-unit-handbook.sh
