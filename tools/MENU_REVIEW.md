# Menu and start flow

The opening screen chooses one or two players. Solo opens the live ride picker;
two players get independent pickers in the shared world's split view. The
selected rider, vehicle and terrain survive Start. The camera turns around the
rider for 1.1 s, then the countdown shows 3, 2, 1 at 0.7 s per number and releases the riders.
The complete camera/countdown sequence is 3.2 s.
Only retries and returning to the opening menu create a new world.

`MenuFlow` fits a 1600×900 design canvas inside the safe-area viewport. Its
vehicle and player illustrations render actual models once into small textures;
these extra scenes do not animate or render continuously during a run. Keyboard,
controller, mouse and touch use the same actions, with separate ready controls
for the two-player lobby.

`CountdownDisplay` owns one replaceable animation, so a delayed fade from the
previous numeral cannot hide the next one. Both solo and split-screen use it.

## Menu music

“Snödag” is an original 16-bar D-major arrangement at 108 BPM (35.56 s):
music-box notes, a soft flute-like lead, accordion offbeats, bass and sleigh bells.
The bundled `audio/menu_snodag.ogg` loops separately from the riding playlist.
Two music players crossfade over the camera turn; pause and saved volume levels
still apply. No composition is rendered while changing menu screens.

Rebuild after editing `MusicComposer.render_menu()`:

```sh
godot --headless --path . --script res://tools/render_menu_music.gd
ffmpeg -y -i /tmp/pulka-menu.wav -c:a libvorbis -q:a 6 audio/menu_snodag.ogg
```

## Verification

```sh
godot --headless --path . --fixed-fps 60 --script res://tools/menu_flow_test.gd -- --mute
godot --path . --fixed-fps 60 --script res://tools/menu_flow_test.gd -- --capture --mute
godot --path . --fixed-fps 60 --script res://tools/menu_flow_test.gd -- --compact --mobile-preview --capture --mute
godot --headless --path . --fixed-fps 60 --script res://tools/controller_menu_test.gd -- --mute
godot --headless --path . --fixed-fps 60 --script res://tools/race_test.gd -- --mute
```

The flow test checks world/mesh identity, unchanged start position, the camera's
position and rotation steps and minimum orbit radius, number order, cancellation
of an outgoing numeral's fade, music switching, locking and independent player
selection. Native review images are saved as `/tmp/pulka-menu-*.png`.

Native verification on the development Mac (Metal Forward+, desktop High):
solo Start spent 0.09 ms on the CPU and race Start 0.21 ms after moving finish-line
preparation into selection. The rendered preview/intro trace had a median near
8.3 ms per frame; this is a finite local measurement, not a device guarantee.
The native flow trace passed without script/render errors, including both
players' camera transitions. A separate sweep covers 0°, 90°, 180° ±0.1° and
360°: the rider stays framed and the camera stays outside the body.

Headless audio tests can emit the engine's audio-resource-in-use warnings on
fast shutdown; their assertions and the native review run pass. The exported
PCK was also loaded independently to check the menu loop, font glyphs/licences
and unchanged world identity when starting.

Settings and pause share the same fitted canvas, card surfaces, fonts and
primary/focus colours as the opening menu. `tools/dialog_test.gd` checks volume
initialisation and audio-bus changes, focus restoration and opening/closing
settings while paused; add `--capture` for native review screenshots.

Fullscreen preferences also save a desktop-only `user://pulka.window.cfg`
override. Godot reads it before creating the first window, so the boot splash
already uses the selected mode. Older saves migrate on their first normal
launch. Mobile, TV, web and the editor do not load this desktop override.
`godot --headless --path . --script res://tools/fullscreen_test.gd -- --native`
checks isolated fullscreen and windowed launches before any scene loads.

The main menu's About button opens credits over the same winter backdrop.
Its Licenses view includes Godot's runtime copyright/license notices and both
bundled font licenses. Keyboard arrows, d-pad and stick scroll the notices;
Back returns through credits to the menu and restores focus to About.
