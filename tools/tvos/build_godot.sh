#!/bin/sh
## Builds the custom Godot 4.7.2 used for the Apple TV version: the official
## 4.7.2-stable source with tvOS support (godotengine/godot#123885, adapted to
## 4.7.2 in godot-4.7.2-tvos.patch). Produces a macOS editor that can export
## to tvOS and the tvOS templates (device and Simulator) in
## ../godot-tvos/bin. Needs Xcode with the tvOS SDK; takes a while.
set -eu

cd "$(dirname "$0")"
patch="$(pwd)/godot-4.7.2-tvos.patch"
source_dir="${GODOT_TVOS_SOURCE:-$(pwd)/../../../godot-tvos}"

if [ ! -d "$source_dir" ]; then
    git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git "$source_dir"
fi
cd "$source_dir"
if ! git log --oneline -1 | grep -q "tvOS platform"; then
    git -c user.name="Pulka" -c user.email="pulka@localhost" am "$patch"
fi
if [ ! -x .venv/bin/scons ]; then
    python3 -m venv .venv
    .venv/bin/pip install -q scons
fi

jobs=$(sysctl -n hw.ncpu)
.venv/bin/scons platform=tvos target=template_release simulator=yes arch=arm64 opengl3=yes -j"$jobs"
.venv/bin/scons platform=tvos target=template_debug simulator=yes arch=arm64 opengl3=yes -j"$jobs"
.venv/bin/scons platform=tvos target=template_release arch=arm64 opengl3=yes -j"$jobs"
.venv/bin/scons platform=tvos target=template_debug arch=arm64 generate_bundle=yes opengl3=yes -j"$jobs"
.venv/bin/scons platform=macos target=editor arch=arm64 vulkan=no accesskit=no angle=no -j"$jobs"
echo "Klart: editor och tvOS-mallar finns i $source_dir/bin."
