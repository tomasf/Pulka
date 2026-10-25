#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
if [ -n "${GODOT:-}" ]; then
    godot_bin="$GODOT"
elif command -v godot >/dev/null 2>&1; then
    godot_bin=godot
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
else
    echo "Godot saknas. Sätt GODOT till sökvägen till Godot 4.7." >&2
    exit 1
fi

mkdir -p export/web
"$godot_bin" --headless --path . --editor --import
"$godot_bin" --headless --path . --script res://tools/bake_web_audio.gd
"$godot_bin" --headless --path . --editor --import
"$godot_bin" --headless --path . --export-release Web export/web/index.html
echo "Webbversionen finns i export/web. Starta: python3 -m http.server 8060 --bind 127.0.0.1 --directory export/web"
