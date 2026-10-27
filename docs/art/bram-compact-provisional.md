# Bram compact video trial

This optional map presentation uses the user-accepted provisional Bram videos. It does not replace combat art, change rules, or claim natural alternating gait. Enable **布拉姆视频关键帧（暂用）** in Pause → sound/motion settings. The local setting defaults off; disabling restores the previous idle and movement resources. Mara, Finn and Oren settings remain independent, including their current animation clocks. Oren's existing 1.05 map scale is unchanged.

## Resource and timing contract

- Art source commit: `e6afe4f5c85c4c18db7f63ae42af0be90b50f561`, 56 PNGs only. All imported PNG Git hashes were compared with that exact tree.
- Four directions under `assets/sprites/iso4/bram_video_provisional/{idle,walk}/`: six idle and eight movement images each.
- Every image is 128×128, root (64,120), at the original body pixel scale. No per-frame alignment, resizing, deformation or disabled depth testing.
- Idle source keys 40,52,58,64,70,76; holds 12,6,6,6,6,5 ticks at 24 Hz: 41/24 seconds per loop.
- Movement source keys 40,43,46,49,52,55,58,60; weights 3,3,3,3,3,3,2,3. The complete 23-weight sequence follows one actual traveled grid, using the existing weighted loader and UnitMotion distance. Logical movement speed is unchanged.
- Neutral guards bind the existing Bram directional idle images. Malformed clips fail closed to previous art. Resource loading and HP body-width measurement remain cached, not per-frame image scans.

## Validation and visual limits

Linux Godot 4.6.3 Compatibility/llvmpipe: actual 1280×800 and 960×600 captures in fixed-background and original 3D views; four legal directional routes, start/stop/turn/skip, paused toggles, save/load, target ghost, HP and settings bounds. The settings panel and all four optional animation controls fit the smaller viewport. Tests verify the other three actors' clocks and textures remain unchanged when Bram is toggled.

The approved source still has conspicuous hammer/arm gestures and torso yaw during idle, narrow steps/occasional foot crossing during movement, and edge shimmer. Source opaque foot rows reach 123 in front views, below the nominal root 120. Maximum-foot-frame captures retain visible shoes, but lowest sole pixels can be intersected by the existing 3D ground/depth plane; this is not claimed to be pixel-perfect foot locking or zero clipping. No root or depth workaround was introduced. Fixed-background and 3D views preserve their existing scale difference.

The delivered four-direction game clip is a 60 Hz fixed-step offline Movie Maker capture: 1,436 frames, 23.933333 seconds, 1280×800. Simulation/playback speed is normal; encoding/render throughput and the visible FPS counter during capture are not hardware performance measurements. Test placements are explicitly labeled; this is not a default campaign playthrough. Review video and screenshots remain outside Git.

Validation result: complete `tools/test.sh` exited 0 with 32,728 assertions, five server/two-client network suites and 30 network movement scenarios. Bram's new tests contribute 438 timing/config checks, 5,560 scene checks and 122 edge/UI checks. The scene test also passed graphically at both resolutions, and the edge test passed graphically with the settings panel visible. All four compact Bram network directions observed 31 ordinary Runtime replacements without restarting presentation or changing authoritative state.

No actual Windows visual test was performed; native code and bundled Windows DLLs are unchanged.

## Reproduction

Run `bash tools/test.sh` for the complete suite, including the three Bram tests and four real-network compact Bram direction scenarios. Individual scripts are `tests/test_bram_sequence.gd`, `tests/test_bram_sequence_scene.gd`, and `tests/test_bram_sequence_edges.gd`.

For optional local screenshots, run the scene test graphically with `AMBER_BRAM_STILLS` set to an existing output directory and the desired viewport resolution. `AMBER_BRAM_SETTINGS` on the edge test captures both settings sizes. For the video, set `AMBER_COMPACT_CAPTURE` to an existing local directory and run `tests/record_bram_sequence.gd` with `--fixed-fps 60 --write-movie /absolute/local/output.avi --resolution 1280x800`; `AMBER_COMPACT_3D=1` selects the original 3D view. These switches affect test capture only, not production defaults.
