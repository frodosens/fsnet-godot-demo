# Foliage, small HUD glyphs and Mara gait integration

2026-10-26. This is an incremental runtime integration, not a claim of one-to-one concept matching or zero foot sliding.

## Assets and actual use

- Art increment `97b20e1`: four 32px source glyphs for HP/MP/movement/action. `ui/responsive_art_icon.gd` selects them when the actual rendered icon size is <=20px; preserves the original texture above that threshold. CanvasLayer's screen transform alone omitted Window canvas-items scaling in the first attempt; the graphical test caught this. Final implementation combines logical canvas transform and physical Window extent. At 960×600, measured 15px/small; at 1920×1080, 27px/large. Both graphical HUD runs passed 21 checks. HiDPI output uses actual pixel extent, but no physical HiDPI monitor was available for OS-specific testing.
- Art increment `2b5c96ad`: independent oak/birch/willow/conifer and round/tall shrub textures. Runtime uses each manifest pixel_size based on visible alpha height; no same-canvas-size shortcut. Large crowns moved outside the tactical area; X obstacle cells use low shrubs and stones. The river's actual W/B rows exclude tree roots, including the third river row which the old hardcoded condition missed. Willow roots are on the bank. No terrain, collision, rules or content hash changed.
- Art increment `c763285`: four knight/front_right contact/pass frames. Whole frames are loaded without bbox/sole re-centering; fixed torso registration preserved. Existing 0.5-world stride at 8 fps remains the conservative tuning. Other 23 role/direction sequences are unchanged.

## Actual visual evidence

Before vegetation: [0226809 same-camera 1280×800 capture](https://github.com/frodosens/fsnet-godot-demo/blob/0226809/docs/reference-hud-1280x800.png).
After vegetation: `docs/foliage-v4-runtime.png`, actual 1280×800 OpenGL rendering, same map/selection/BFS route/camera. `foliage-v4-counts.json` records all instances and projected alpha bounding rectangles intersecting the viewport: oak 7, birch 15, conifer 6, willow 2, round shrub 30, tall shrub 14. These are conservative bounds counts, not visible-pixel/occlusion counts. Zero roots on walkable cells; zero prop alpha bounding rectangles cover the demonstrated path's cell centers. This is not exhaustive proof for every possible camera or path.

`docs/reference-hud-960x600.png` validates new small icons against the previous vegetation scene, deliberately separating the glyph change from later foliage work.

`docs/runtime-video/mara-gait-before-after.mp4` is a real 10-second 1280×800 MovieMaker capture at fixed 30 fps, silent: first old textures, then new textures; same +X path [(4,7),(5,7),(6,7),(7,7)], same 1× speed/camera/stride. Both finish with hash `d609c6cffc8f2fd0d6384c816f4a2a5c4320dc405bd1aa58e70d92aff7f03ecb`. The old images are loaded from an explicit local fixture directory by `record_gait_comparison.gd`; they are not silently substituted into production. The video predates the final two tree-root relocations; use the final PNG for foliage placement. Recording took about 63 seconds on llvmpipe, so encoded 30 fps is not an achieved hardware frame rate.

## Validation / limits

Full regression: 550 counted checks and all four real fsnet three-process/reconnect scenarios passed. Final bank-root-only adjustment was additionally checked with 49 contact/path/crit assertions and real capture/placement statistics. No new gameplay state is introduced.

Visual inspection of the recorded new contact/pass samples shows distinct legs rather than the previous near-duplicate support pairs. It does not establish zero ground drift: four discrete held frames and predominantly horizontal source-foot sweep still leave possible vertical drift on the isometric ground plane. The supplied registration metadata has torso placement/bounds/hashes, not per-foot contact coordinates; precise foot-lock measurement is not claimed. Foot socket annotations (which foot, x/y in the 96×128 canvas, stance interval) would support further per-direction calibration. No speculative per-frame root-counter-jitter was added.

Trees are still shaded 2.5D cards, not volumetric meshes, and their directionality does not support arbitrary camera rotation. Current fixed tactical camera is the validated view. Repeated shrubs, geometric river edges, roof/inn composition and water reflection remain below the approved concept. Android remains paused with local uncommitted drafts; no dependencies installed or licenses accepted.
