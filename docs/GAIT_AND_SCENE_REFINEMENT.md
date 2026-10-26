# Distance-driven gait and scene refinement

2026-10-26, following visual baseline becc049. Android work is paused; its local preparation drafts are excluded from this increment.

## Implemented

- `view/unit_motion.gd` no longer pairs an independent 0.5-second tile tween with an 8 fps clock. Per-role/per-direction `assets/sprites/iso4/gait.json` defines fps and stride distance. World velocity = stride × fps / frame count; frame phase accumulates actual distance / stride. Initial conservative tuning is 0.5 world units per four-frame cycle at 8 fps (1 tile/second), previously 1 tile per cycle (2 tiles/second).
- Fast-forward scales one elapsed-time budget; displacement and frames accelerate together. A long frame consumes each canonical path segment in order; corners retain gait phase. Skip/new authoritative step settles to the authoritative cell and idle pose. No rules, RNG, snapshot or content hash changes.
- World labels now use compact raster HP frame/fill instead of persistent names/numbers above every unit. Names and exact values remain in selected/target HUD. Decorative river-bank stones are lower/staggered with gaps; tactical terrain tile surfaces meet without black physical seams. Water/bridge/obstacle rules are unchanged.
- Capture tool places the actual pointer over the destination before the preview capture, avoiding an unrelated OS mouse move clearing the route.

## Actual evidence

- Complete `tools/test.sh`: 542 counted checks, no errors/failures, all four real fsnet server+two-client/reconnect scenarios passed. Added 32 gait checks cover 24 role/direction resources, derived velocity/phase, 2× playback, corner continuity, timestep partition, large delta/settling, skip and snapshot invariance. Tests cannot prove foot contact quality.
- `docs/reference-hud-1280x800.png`: actual Godot OpenGL scene with path preview. This increment captured 1280×800 only; prior three/six-resolution UI evidence remains in the preceding reports and is not relabeled as a new six-resolution run.
- `docs/runtime-video/distance-driven-walk.mp4`: actual 1280×800, 30 fps MovieMaker output, 10.6 seconds. Automated keyboard/mouse action selection, one target click, full three-tile movement, and spent-action return. Silent. Mesa llvmpipe software rendering took about 66 seconds; the encoded 30 fps is not a hardware performance benchmark.

## Unresolved visual acceptance

This improves clock/stride coordination; it does **not** certify zero foot sliding. The source art has only four discrete poses. In knight/front_right, frames 00/01 retain a very similar near-foot contact, and 02/03 similarly hold the opposite extended leg. Continuous root travel can still move a held support foot on screen. These specific pairs need artist contact/pass-phase revision; a generic root-position counter-jitter would hide the issue while distorting the path. Initial 0.5 stride values are explicit tuning, not anatomical measurements of all six characters.

The river bank remains geometric, the inn/river composition and vegetation are not a one-to-one match for the approved concept. Existing repeated tree cards remain inadequate; new species/silhouette assets are pending from the art task. No replacement tree assets were invented or claimed integrated here. Water reflection and fully natural shoreline transitions remain below the concept. Original GBA combat presentation is separate from this map gait work.
