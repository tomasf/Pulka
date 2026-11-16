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

rm -rf export/macos
mkdir -p export/macos
"$godot_bin" --headless --path . --editor --import
"$godot_bin" --headless --path . --export-release macOS export/macos/Pulka.app
codesign --verify --deep --strict export/macos/Pulka.app
echo "Mac-appen finns i export/macos/Pulka.app."
