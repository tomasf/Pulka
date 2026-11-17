# Streaming hitch investigation

Measured on the development Mac, Godot 4.7.2, with fixed world seed 4711.
The cold streaming run advances 9.6 km in 16,000 updates at 36 m/s,
without entering and warming a target region before timing it.

| Version | Worst world update | Updates over 8 ms |
| --- | ---: | ---: |
| Before | 74.97 ms | 11 |
| Shared crowd poses, preparation spread across frames | 18.32 ms | 9 |
| Painted floors also prepared row by row | 11.92 ms | 2 |
| Model resources loaded before play | 5.84 ms | 0 |
| Also shared primitive CPU geometry, final verification | 4.05 ms | 0 |

The median remained 0.21 ms; final p99 was 3.00 ms. These are
CPU timings for `SlopeWorld.update_world`, not total rendered frame times.
Results can vary with hardware and system load.

The largest stalls were crowd pose skinning in bandy stands (up to 74.58 ms
for one scenery stage), followed by mall/rink floor generation. A separate
resource load measurement found the bear resource alone took 10.11 ms to
load synchronously. The renderer and models are retained; no detail reduction
was used to achieve these results.

Crowd geometry is now cached by model/clip/phase, with clothing assigned as
shared material overrides. Missing poses and painted floors are prepared
within the streaming budget before the player reaches them. Removed chunks
cancel their pending work. Immediate `Props.posed` callers and tools retain
the synchronous path. Model scene resources load with the game scripts.

## Native rendering

A separate 1,500-frame autopilot ride into bandy (seed 4711, desktop High,
Metal Forward+, first 180 frames excluded) exposed additional costs hidden
by the headless renderer:

| Version | Median frame | p99 | Worst frame | Frames over 16.7 ms |
| --- | ---: | ---: | ---: | ---: |
| Streaming fixes above, original primitive reads and live music synthesis | 11.36 ms | 17.88 ms | 76.35 ms | 21 |
| Shared box/sphere/cylinder CPU geometry | 11.16 ms | 16.89 ms | 20.39 ms | 17 |
| Also use baked audio, final verification | 8.34 ms | 9.40 ms | 16.66 ms | 0 |

`PrimitiveMesh.get_mesh_arrays()` goes through the rendering server. Repeated
reads of fresh boxes and wheels stalled native road construction, including a
58 ms stage in the first deterministic ride. Common unit geometry is now read
once and scaled on the CPU. Position, normal and winding equivalence is checked
against the original primitives.

Desktop also started seven music synthesis threads while the player was riding.
It now prefers the same pre-rendered audio already used on web/Apple TV, and the
macOS export script bakes and includes it. Source checkouts without a complete
audio set retain the synthesis fallback; run the baking command below first.
Regenerate audio after changing `Synth` or `MusicComposer`.

These are finite traces, not a guarantee of every frame on every system. The
first baked-audio check had three frames over 16.7 ms (worst 32.30 ms); its
largest pause was outside world generation. The final repeat above had none.
GPU timings are unavailable through Godot's timing API on this Metal renderer.

## Reproduce

```sh
godot --path . --headless --fixed-fps 60 --script res://tools/stream_profile.gd -- 16000
godot --path . --headless --script res://tools/bake_web_audio.gd
godot --path . --fixed-fps 60 --script res://tools/ride_profile.gd -- bandy --mute
godot --path . --headless --script res://tools/pose_cache_test.gd
godot --path . --headless --script res://tools/floor_prepare_test.gd
godot --path . --headless --script res://tools/mesh_kit_test.gd
```

`stream_profile` prints per-stage timings; `ride_profile` runs full game logic
and rendering. Add `--capture` to save `/tmp/pulka-profile-ride.png` outside
the timed sample. Frame durations are measured individually; Godot's
`Performance.TIME_PROCESS` reports a one-second maximum and must not be
used as a per-frame percentile. The older `hitch_test`
preloads its target region and then jumps backwards, so its initial forced
rebuild and warmed caches are not directly comparable with the cold trace.
