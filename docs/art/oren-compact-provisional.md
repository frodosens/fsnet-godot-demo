# Oren provisional compact idle and motion

Art source: `da5ea98bf7f23eca01c8c83989b386aaa2a61d2f`. Exactly 56 RGBA PNGs:
24 selected latest-v3 idle images and 32 separate-v2 movement images. The failed
8-cell attempt and rejected earlier idle are not used. No source video, full-frame
sequence, GIF or demonstration media is committed.

Pause → 音效与动态效果 → 奥伦视频关键帧（暂用） enables an independent, local,
off-by-default trial. Disable it to restore Oren's old idle and walk/static
fallback. Mara and Finn keep their own independent switches and phases. The
preference is not shared gameplay state, and does not change save/network hashes.

## Timing and geometry

All admitted images are 128×128 with root (64,120). Padding does not shrink the
body. The existing Oren 1.05 map render factor remains in its original location
and is applied exactly once. It is not baked into the images, and never changes
movement velocity, portraits or side-view combat.

Each direction has six idle keys (source 41,49,57,65,73,81), each held eight ticks
at 24 Hz: 48 ticks, exactly two seconds per idle loop. Each movement direction has
eight keys (43,48,53,58,64,69,74,79) with weights 5,5,5,6,5,5,5,6, totaling 42.
The source's natural motion duration is 1.75 seconds; runtime instead maps these
relative weights to **one actually traveled grid unit**, preserving the established
0.8 s/grid reference-map speed and 1 s/grid 3D speed before normal speed controls.
No independent movement animation clock is introduced.

The loader adds only a validated `idle_canvas_width` of 96 or 128; existing Mara
and Finn manifests retain their old defaults and timing. The original 96-wide
neutral remains the identity guard. Incomplete/invalid canvas or duration values
fail the entire affected profile safely without disabling other valid profiles.

## Explicit visual limits

This is the knowingly accepted provisional asset set, not a claim of improved
upright anatomy or natural alternating gait. Crouched/posture differences,
shuffle-like motion, detail changes and some apparent sliding remain. Idle opaque
feet end at row 119; movement can reach inclusive rows 120–121 in the front views,
118–119 back-left and 119 back-right. Depth tests remain enabled, so ground can
clip pixels below root 120. No per-frame recenter, scale correction, limb edit,
IK, redraw or depth-disable workaround is applied.

## Verification and reproduction

- `tests/test_oren_sequence.gd`: every idle/motion weight, padded canvas, cycle wrap,
  invalid fields, profile isolation and all eight three-switch combinations.
- `tests/test_oren_sequence_scene.gd`: four directions in fixed/3D views; actual rule
  paths and traveled distance, exact 1.05 factor, root, HP, paused toggle, stop/skip.
  `AMBER_OREN_STILLS` optionally writes local-only graphical snapshots.
- `tests/test_oren_sequence_edges.gd`: actual mouse/keyboard switch, other actors'
  phases/images, previews, turns, large delta, duplicate events, save/load, two sizes.
- `AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=oren AMBER_WALK_DIRECTION=<direction>
  python3 tests/run_walk_network.py`: real authority/client Runtime replacements.
- `tests/record_oren_sequence.gd`: explicitly labeled legal test placements and
  real movement commands, not a claim of default story progression. Set
  `AMBER_COMPACT_CAPTURE` to an existing local folder. `--fixed-fps 60 --write-movie`
  preserves normal simulation time in offline capture; onscreen FPS during capture
  is export throughput, not a hardware benchmark.

Visual checks use Linux Godot 4.6.3 Compatibility/llvmpipe at 1280×800 and 960×600.
They do not establish Windows visual performance. Native/shared logic and all
other art files remain unchanged. Candidate publication is separate from main
acceptance; demo delivery uses Library only.

Validation: complete `tools/test.sh` exited 0 with 26,608 reported checks, five
base network scenarios, target-confirmation networking and 26 movement-network
runs (14 old, four each Mara/Finn/Oren compact). Each Oren run observed 31 Runtime
replacements. The four-direction graphical scene tests reported 5,560 checks at
each tested resolution; the final mouse/keyboard/settings test reported 86 passes.
All 56 PNG blobs match the source commit. The delivered actual-game preview is
1,436 encoded frames at 60 fps, 23.933333 seconds, normal-time offline capture.
