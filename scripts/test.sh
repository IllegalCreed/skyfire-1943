#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

game_engine="${SKYFIRE_GODOT:-$PWD/work/tools/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$game_engine" ]; then
  echo 'Godot not found. Run bash scripts/bootstrap-macos.sh or set SKYFIRE_GODOT.' >&2
  exit 1
fi

mkdir -p work
touch work/.gdignore
smoke_log="$PWD/work/test-smoke.log"
"$game_engine" --headless --path "$PWD" --quit-after 8 --log-file "$smoke_log" -- --smoke

if rg -n 'SCRIPT ERROR|ERROR:|Assertion failed' "$smoke_log"; then
  echo 'Smoke checks failed.' >&2
  exit 1
fi
if ! rg -q '^SMOKE PASS:' "$smoke_log"; then
  echo 'Smoke checks did not finish.' >&2
  exit 1
fi
ruby scripts/check-docs.rb
