# Finn motion-only compact trial

Art source: `badc4db389e8bc250e2376e809e979589174d911`. Exactly 32 PNGs are
admitted: eight movement keyframes for each of four diagonal facings. The source
video's idle panels did not pass separation, so **all existing Finn idle art and
idle playback remain unchanged**. No video, source sheet or diagnostic image is
included in Git.

Pause → 音效与动态效果 → 芬恩视频移动（候选） enables a local, off-by-default
motion trial. Disable it to recover the previously accepted three-pose motion
where available and static neutral fallback elsewhere. This setting is independent
of the Mara trial, persists locally, and is not part of rules/saves/network hashes.
Changing one actor's option does not restart the other actor's idle phase or image.

## Runtime contract

- Canvas 128×128, root (64,120), unchanged body pixel scale. The extra 16 pixels on
  either side are padding. No resizing to 96 pixels or per-frame alignment occurs.
- Selected source indices: 30,34,37,40,43,46,49,52. Holds: 4,3,3,3,3,3,3,3 (25 ticks).
  At the source's 24 Hz this corresponds to 1.041667 seconds, **not** an added
  gameplay timer. The hold fractions are mapped to one actually traveled grid unit.
- Existing world speed remains unchanged: 0.8 s/grid in the reference fixed
  background and 1 s/grid in 3D, before the existing speed multiplier.
- `motion_only: true` explicitly omits idle; contradictory idle fields fail closed.
  `cycle_ticks` defaults to 38 for the existing Mara profile and must equal the
  bounded integer hold sum. Malformed profiles fall back atomically, without
  invalidating the other valid actor profile. Canonical neutral identity guards
  continue to apply. Textures and conservative HP width are cached.
- Stops return to Finn's original idle; no synthetic neutral or modified source
  pixels are substituted. All other actors, Oren's 1.05 scale, battle cut-ins and
  native/shared gameplay logic are unchanged.

## Visual limits

The four sequences show alternating leading boots, unlike the prior Mara shuffle.
This does not establish physically locked feet or perfect full-body anatomy. Small
silhouette/detail changes at the transition from old idle to the new motion remain
possible. The supplied silhouette reaches exclusive bottom 122 in its fixed union,
so pixels may extend below nominal root 120. Original depth tests remain enabled;
3D ground can clip the lowest source rows. No per-frame offsets, altered ground,
IK, limb mirroring, redraw or depth-disable workaround is used.

## Reproduce validation

`tools/test.sh` includes weighted tick/type/fallback checks, both actor options,
scene/pause/skip/turn/preview/save checks and real network polling tests. The Finn
network variants set `AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=finn` and each of
`front_left`, `front_right`, `back_left`, `back_right` as `AMBER_WALK_DIRECTION`.

Graphical checks use `tests/test_finn_sequence_scene.gd` (optional
`AMBER_FINN_STILLS=/absolute/existing/local/directory`) and
`tests/test_finn_sequence_edges.gd`, at 1280×800 and 960×600, fixed and 3D.
`tests/record_finn_sequence.gd` records real legal movement commands from labeled
test placements. It retains normal simulation time. A 60 fps `--write-movie`
export is offline capture; onscreen FPS during export is throughput, not a hardware
benchmark. Keep all output screenshots/recordings outside Git; use Library delivery.

Testing is Linux Godot 4.6.3 Compatibility/llvmpipe, not Windows visual validation.
The assets and runtime switch remain a review candidate; no claim of final gait
acceptance or general completion of other video-derived characters is made.

Validation result: complete `tools/test.sh` exited 0 with 20,484 reported checks,
five base network scenarios, target-confirmation networking and 22 walk network
runs (14 old, four Mara compact, four Finn compact). Each Finn run observed 31
Runtime replacements with uninterrupted distance phase. Graphical scene checks
reported 5,552 passes at each tested resolution; the final graphical interaction
suite reported 82 passes. All 32 art blobs match the source commit. Delivered
video: 1,276 frames / 60 fps / 21.266667 seconds, normal-time offline capture.
