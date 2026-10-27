# Mara compact map sequence trial

This is a reversible, **off-by-default** art trial, not acceptance of a natural walk.
In battle pause → 音效与动态效果 → 玛拉视频关键帧（候选） enables it. Disable the
same local checkbox to restore the accepted old idle/three-pose walk. The option
is a local presentation preference and is absent from saves, rules and network
snapshots. It applies only to the unit ID `mara` with the matching canonical
neutral texture; other units, portraits and side-view combat stay unchanged.

## Admitted images and timing

Art source commit: `ede23c6185d5085d96026aaa2fee43e4f749602e` (56 PNGs only).
There are six idle and eight motion images per facing. Full 38-frame sequences,
source videos, diagnostic variants and demonstration recordings are not vendored.
Runtime timing is independently defined in `assets/animations/map_sequences.json`.
Each idle loop has 38 ticks at 24 ticks/s (1.583333 s). Motion uses the same
nonuniform hold weights as **relative phase weights over one actual traveled
world-grid unit**. It does not have an independent animation clock and does not
use the older N/L/N/R indexing. Fixed-background movement still takes 0.8 s/grid,
and the original 3D mode takes 1 s/grid, before existing speed controls.

Idle canvas/root: 96×128 / (48,120). Motion canvas/root: 128×128 / (64,120).
The extra width is transparent padding; pixel size, world root and vertical
offset are unchanged. No per-frame rescaling, recentering, IK, warping, redraw or
depth-disable workaround is applied. All images are cached once; health-bar body
width is measured conservatively across admitted textures when the option changes,
not scanned every update. Invalid/incomplete profiles fail atomically to old art
and expose loader diagnostics. Neutral texture identity guards against unintended
application to a differently styled Mod unit with the same ID.

## Observed limits and production gate

The motion depicts repeated same-foot lifting/shuffling, not verified alternating
left/right support. Idle and motion also differ slightly in silhouette and detail;
small edge shimmer/green residue remains in the source. At alpha >=128 the selected
motion frames have inclusive bottom rows up to 121, versus idle up to 119. Thus
some motion pixels are below the nominal foot root. Normal depth tests remain on;
the 3D ground may clip those lowest one or two source rows. A fixed root does not
mean zero skating or identical visible foot position. No anatomy correction or
full production-walk acceptance is claimed.

Future character generation must identify anatomical left/right legs, visibly
alternate the lead/support legs and review the loop at actual map size. A changing
silhouette alone is insufficient. Retain stable hands/weapons and compare starts,
stops and turns; do not hide a failed leg cycle with speed, mirroring or offsets.

## Reproduction and scope of evidence

- `tests/test_map_sequence.gd`: timing ticks, type/path/root validation, atomic fallback.
- `tests/test_map_sequence_scene.gd`: four facings × both render modes, authoritative
  movement distance, padding/root, cached HP, pause, zero speed, skip and reversible toggle.
- `tests/test_map_sequence_edges.gd`: actual mouse/keyboard checkbox input at 1280×800
  and 960×600, previews, legal turns, duplicate events, fast/large delta, save/load.
- `AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=mara AMBER_WALK_DIRECTION=front_right
  python3 tests/run_walk_network.py` (also front_left, back_left, back_right): real
  authority/client polling and Runtime replacement during motion.
- `tests/record_map_sequence.gd` uses explicitly labeled legal test placements, not
  default story progression. Set `AMBER_COMPACT_CAPTURE` to an existing local folder;
  optionally `AMBER_COMPACT_3D=1`. Use Godot `--fixed-fps 60 --write-movie /absolute/local.avi`
  for offline recording at normal simulation timing. Onscreen FPS during this export
  is capture throughput, not playback cadence or a hardware benchmark.

Visual checks use Linux Godot 4.6.3 Compatibility/llvmpipe. They do not establish
Windows, Android, or hardware GPU performance. Source code/native dependencies,
logical movement speed, all other actors and Oren's 1.05 map scale are unchanged.
Demo screenshots/videos remain outside Git and are delivered through Library.

Candidate validation (Linux 4.6.3): complete `tools/test.sh` exited 0 with 14,708
reported checks, existing authority/target-confirmation network suites and 18
walk network runs (14 original, four compact Mara facings). Each compact run saw
31 Runtime replacements without restarting travel. Actual graphical checks at
1280×800/960×600 covered both scene modes; the focused GUI test reported 74 checks
and the four-direction scene test 5,552. All 56 PNG blobs were rechecked against
the art commit. The delivered 21.266667-second preview has 1,276 encoded frames at
60 fps and uses offline fixed-step capture, not a real-time performance benchmark.
