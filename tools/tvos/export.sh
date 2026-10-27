#!/bin/sh
## Exports the Apple TV version as an Xcode project in export/tvos.
##
## Godot has no official tvOS support, so this uses a custom Godot 4.7.2
## build with the tvOS platform from godotengine/godot#123885, kept in
## ../godot-tvos (override with GODOT_TVOS_SOURCE). See tools/tvos/build_godot.sh for
## how that build is made. The script installs its tvOS templates next to
## the official 4.7.2 ones and adds the tvOS export preset if it is missing
## (the official editor drops presets for platforms it does not know).
set -eu

cd "$(dirname "$0")/../.."
source_dir="${GODOT_TVOS_SOURCE:-../godot-tvos}"
editor="$source_dir/bin/godot.macos.editor.arm64"
templates="$source_dir/bin/godot_tvos.zip"
template_dir="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"

for file in "$editor" "$templates"; do
    if [ ! -f "$file" ]; then
        echo "Saknas: $file. Bygg Godot med tvOS-stöd först (kör tools/tvos/build_godot.sh)." >&2
        exit 1
    fi
done

mkdir -p "$template_dir"
cp "$templates" "$template_dir/tvos.zip"

if ! grep -q '^platform="tvOS"' export_presets.cfg; then
    index=$(grep -c '^\[preset\.[0-9]*\]$' export_presets.cfg)
    cat >> export_presets.cfg <<EOF

[preset.$index]

name="tvOS"
platform="tvOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tools/*, music_preview/*, icons/*"
export_path="export/tvos/Pulka.ipa"
script_export_mode=2

[preset.$index.options]

application/app_store_team_id="4R2KAE48H2"
application/export_project_only=true
application/bundle_identifier="se.tomasf.pulka"
application/short_version="0.1"
application/version="1"
application/export_method_debug=1
application/export_method_release=0
application/code_sign_identity_release="Apple Development"
architectures/arm64=true
icons/tvos_small_app_icon_back_layer="res://icons/tv_icon_back_400x240.png"
icons/tvos_small_app_icon_front_layer="res://icons/tv_icon_front_400x240.png"
icons/tvos_large_app_icon_back_layer="res://icons/tv_icon_back_1280x768.png"
icons/tvos_large_app_icon_front_layer="res://icons/tv_icon_front_1280x768.png"
icons/tvos_top_shelf="res://icons/top_shelf_1920x720.png"
icons/tvos_top_shelf_wide="res://icons/top_shelf_wide_2320x720.png"
EOF
fi

mkdir -p export/tvos
# Apple TV plays audio baked ahead of time (see SoundBank.uses_baked_audio).
"$editor" --headless --path . --editor --import
"$editor" --headless --path . --script res://tools/bake_web_audio.gd
"$editor" --headless --path . --editor --import
"$editor" --headless --path . --export-release tvOS export/tvos/Pulka.ipa
# Running from Xcode otherwise validates every Metal call and keeps GPU frame
# capture ready, which costs the CPU a lot per draw call. Turn both off.
scheme=export/tvos/Pulka.xcodeproj/xcshareddata/xcschemes/Pulka.xcscheme
if ! grep -q enableGPUValidationMode "$scheme"; then
    sed -i '' 's/^\( *\)<LaunchAction$/&\
\1   enableGPUFrameCaptureMode = "3"\
\1   enableGPUValidationMode = "1"/' "$scheme"
fi
echo "Apple TV-versionen finns som Xcode-projekt i export/tvos."
